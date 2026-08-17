# frozen_string_literal: true

require "csv"

# The LOINC release is not in this repository — it carries its own licence — so
# the curation specs run against a handful of real rows copied out of it, and
# build worksheets the way a curator hands them back.
module LoincFixture
  SAMPLE = "spec/fixtures/loinc_sample.csv"

  def loinc_catalogue
    @loinc_catalogue ||= Dictionary::LoincCatalogue.from_path(Rails.root.join(SAMPLE))
  end

  def worksheet(rows, headers: Dictionary::LoincMapping::REQUIRED_COLUMNS)
    path = Rails.root.join("tmp/spec_loinc_#{SecureRandom.hex(4)}.csv")
    FileUtils.mkdir_p(path.dirname)

    CSV.open(path, "w") do |csv|
      csv << headers
      rows.each { |row| csv << row }
    end

    path
  end
end

RSpec.configure do |config|
  config.include LoincFixture
end
