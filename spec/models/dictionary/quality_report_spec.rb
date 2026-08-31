# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dictionary::QualityReport do
  # The fixture carries the same defects the real mLab database has, so the
  # report is checked against them rather than against invented data.
  context "with the sample dictionary imported" do
    before { Dictionary::MlabImporter.new(source: MlabFixtureSource.load).call }

    let(:report) { described_class.new }

    def issues(kind)
      report.rows.select { |issue| issue.issue == kind }
    end

    it "finds the two entries sharing a name" do
      expect(issues("duplicate_name").map(&:name)).to eq([ "Hemoglobina", "Hemoglobina" ])
      expect(issues("duplicate_name").first.detail).to match(/mesmo nome que MOZ-TI-\d{4}/)
    end

    it "finds the indicator that belongs to no test" do
      expect(issues("indicator_without_test_type").length).to eq(1)
    end

    it "finds the numeric indicator with no reference interval" do
      expect(issues("numeric_indicator_without_range").map(&:name)).to eq([ "Leucócitos" ])
    end

    it "finds the inverted interval" do
      expect(issues("invalid_range").map(&:detail)).to eq([ "intervalo invertido (20.0 > 10.0)" ])
    end

    it "finds the test that reports nothing" do
      expect(issues("test_type_without_indicators").map(&:name)).to eq([ "Urina II" ])
    end

    it "finds the test with nothing to collect" do
      expect(issues("test_type_without_specimen_types").map(&:name)).to eq([ "Cultura de sangue" ])
    end

    it "finds the specimen type no test uses" do
      expect(issues("specimen_type_without_test_types").map(&:name)).to eq([ "Expectoração" ])
    end

    it "finds the drug no organism is tested against" do
      expect(issues("drug_without_organisms").map(&:name)).to eq([ "Gentamicina" ])
    end

    it "finds the organism no test isolates" do
      expect(issues("organism_without_test_types").map(&:name)).to eq([ "Klebsiella pneumoniae" ])
    end

    it "finds the empty panel" do
      expect(issues("test_panel_without_test_types").map(&:name)).to eq([ "Painel vazio" ])
    end

    it "reports nothing about the entries that are complete" do
      expect(report.rows.map(&:name)).not_to include("Hemograma completo")
    end

    it "counts the issues by kind, worst first" do
      expect(report.counts.values).to eq(report.counts.values.sort.reverse)
    end

    it "writes a csv an operator can work through" do
      path = report.write_csv("tmp/quality_spec.csv")
      rows = CSV.read(path)

      expect(rows.first).to eq(described_class::HEADERS)
      expect(rows.length).to eq(report.rows.length + 1)
    ensure
      FileUtils.rm_f(path)
    end
  end

  context "with a dictionary that has nothing wrong with it" do
    before do
      department = create(:department)
      indicator = create(:indicator, value_type: "Free Text")
      specimen_type = create(:specimen_type)
      organism = create(:organism)
      drug = create(:drug)

      test_type = create(:test_type, department: department)
      test_type.indicators << indicator
      test_type.specimen_types << specimen_type
      test_type.organisms << organism
      organism.drugs << drug

      create(:test_panel).test_types << test_type
    end

    it "finds no issues" do
      expect(described_class.new.rows).to be_empty
    end
  end
end
