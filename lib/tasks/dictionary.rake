# frozen_string_literal: true

# Loading and publishing the national dictionary. Only the national node owns
# it, so these refuse to run anywhere else.
#
#   bin/rails dictionary:import_from_mlab
#   bin/rails dictionary:quality
#   ACTOR="Kelven" SKIP_BLOCKED=1 bin/rails dictionary:promote
#   bin/rails dictionary:status

namespace :dictionary do
  task national_only: :environment do
    next if SislabSync.national?

    abort "The dictionary is owned by the national node; this node is running in #{SislabSync.mode} mode."
  end

  desc "Import the dictionary from the SISLAB/mLab database (everything arrives as a draft)"
  task import_from_mlab: :national_only do
    source = Dictionary::MlabSource.from_env
    puts "Reading from #{source.describe}"

    importer = Dictionary::MlabImporter.new(source: source).call

    puts "\nImported:"
    puts importer.summary

    if importer.skipped.any?
      puts "\nSkipped:"
      importer.skipped.each do |skip|
        puts format("  %-16s id=%-8s %s", skip[:entity_type], skip[:external_code], skip[:reason])
      end
    end

    Rake::Task["dictionary:quality"].invoke
  end

  desc "Write the dictionary quality report to tmp/dictionary_quality.csv"
  task quality: :national_only do
    report = Dictionary::QualityReport.new
    path = report.write_csv

    puts "\nQuality report: #{path}"

    if report.rows.empty?
      puts "  no issues found"
    else
      report.counts.each { |issue, count| puts format("  %-38s %5d", issue, count) }
      puts format("  %-38s %5d", "total", report.rows.length)
    end
  end

  desc "Promote every draft to active (ACTOR required, SKIP_BLOCKED=1 to hold back unusable tests)"
  task promote: :national_only do
    actor = ENV["ACTOR"].presence || abort("Set ACTOR to the person accepting these entries.")

    promotion = Dictionary::Promotion.new(
      actor: actor,
      skip_blocked: ENV["SKIP_BLOCKED"].present?
    ).call

    puts "Promoted by #{actor}:"
    puts promotion.summary
  end

  desc "Show what the dictionary currently holds"
  task status: :environment do
    puts "Cursor: #{Dictionary.cursor}"
    puts format("%-16s %8s %8s %8s", "entity", "draft", "active", "retired")

    Dictionary::ENTITIES.each_key do |entity_type|
      model = Dictionary.model_for!(entity_type)
      puts format("%-16s %8d %8d %8d", entity_type, model.drafts.count, model.active.count, model.retired.count)
    end
  end
end
