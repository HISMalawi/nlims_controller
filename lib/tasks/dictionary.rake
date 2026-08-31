# frozen_string_literal: true

# Loading and publishing the national dictionary. Only the national node owns
# it, so these refuse to run anywhere else.
#
#   bin/rails dictionary:snapshot               # mLab -> db/dictionary/mlab_catalog.json
#   bin/rails dictionary:seed                   # that file -> a new national node
#   bin/rails dictionary:import_from_mlab       # from the mLab database
#   bin/rails dictionary:import_from_mlab_api   # from the mLab API
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
    import_the_dictionary(Dictionary::MlabSource.from_env)
  end

  desc "Import the dictionary from the mLab API (MLAB_API_URL, and MLAB_API_TOKEN or MLAB_API_USER/PASSWORD)"
  task import_from_mlab_api: :national_only do
    import_the_dictionary(Dictionary::MlabApiSource.from_env)
  end

  desc "Take the mLab catalogue into a file the seed can load (SOURCE=api|database, OUT=path)"
  task snapshot: :environment do
    source = case ENV.fetch("SOURCE", "api")
    when "api" then Dictionary::MlabApiSource.from_env
    when "database" then Dictionary::MlabSource.from_env
    else abort "SOURCE is api or database."
    end

    puts "Reading from #{source.describe}"
    path = Dictionary::SnapshotSource.write(source, ENV.fetch("OUT", Dictionary::SnapshotSource::DEFAULT_PATH))

    puts "\nCatalogue: #{path} (#{ActiveSupport::NumberHelper.number_to_human_size(path.size)})"
    Dictionary::SnapshotSource::ENTITIES.each do |entity|
      puts format("  %-28s %6d", entity, source.public_send(entity).length)
    end

    print_warnings(source)
  end

  desc "Load the catalogue shipped with the release onto a new national node and publish it (ACTOR=..., SKIP_BLOCKED=1)"
  task seed: :national_only do
    seed = Dictionary::Seed.new(
      source: Dictionary::SnapshotSource.load(ENV.fetch("SNAPSHOT", Dictionary::SnapshotSource::DEFAULT_PATH)),
      actor: ENV["ACTOR"].presence || Dictionary::Seed::ACTOR,
      skip_blocked: ENV["SKIP_BLOCKED"].present?
    )

    puts "Reading from #{seed.source.describe}"
    seed.call

    puts "\nImported:"
    puts seed.importer.summary
    puts format("  %-16s %4d criados  %4d já existiam", "rejection_reasons",
                seed.reasons_created, Dictionary::Seed::REJECTION_REASONS.length - seed.reasons_created)

    print_skipped(seed.importer)
    print_warnings(seed.source)

    puts "\nPublished:"
    puts seed.promotion.summary

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

  desc "Pull the dictionary from the national node (local nodes only)"
  task pull: :environment do
    abort "Only a local node pulls the dictionary; this node is national." unless SislabSync.local?

    puller = Dictionary::Puller.from_env.call
    puts "Pulled: #{puller.summary}"

    cursor = SyncCursor.for(SyncCursor::DICTIONARY)
    puts "Cursor: #{cursor.value} (last synced #{cursor.last_synced_at})"
  end

  desc "Show what the dictionary currently holds"
  task status: :environment do
    if SislabSync.local?
      cursor = SyncCursor.for(SyncCursor::DICTIONARY)
      puts "Pulled up to: #{cursor.value} (last synced #{cursor.last_synced_at || 'never'})"
      puts "Last error:   #{cursor.last_error}" if cursor.last_error.present?
    else
      puts "Cursor: #{Dictionary.cursor}"
    end

    puts format("%-16s %8s %8s %8s", "entity", "draft", "active", "retired")

    Dictionary::ENTITIES.each_key do |entity_type|
      model = Dictionary.model_for!(entity_type)
      puts format("%-16s %8d %8d %8d", entity_type, model.drafts.count, model.active.count, model.retired.count)
    end
  end

  # Both imports run the same way; only where the rows are read from differs.
  def import_the_dictionary(source)
    puts "Reading from #{source.describe}"

    importer = Dictionary::MlabImporter.new(source: source).call

    puts "\nImported:"
    puts importer.summary

    print_skipped(importer)
    print_warnings(source)

    Rake::Task["dictionary:quality"].invoke
  end

  # Rows the importer would not take, named so the laboratory can go and fix
  # them upstream.
  def print_skipped(importer)
    return if importer.skipped.empty?

    puts "\nSkipped:"
    importer.skipped.each do |skip|
      puts format("  %-16s id=%-8s %s", skip[:entity_type], skip[:external_code], skip[:reason])
    end
  end

  # What the source could not read. The API has gaps the database does not, and
  # they belong in front of whoever is promoting these entries.
  def print_warnings(source)
    warnings = source.try(:warnings).to_a
    return if warnings.empty?

    puts "\nAvisos da fonte:"
    warnings.each { |warning| puts "  #{warning}" }
  end
end
