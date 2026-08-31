# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dictionary::LoincCoverage, mode: :national do
  it "conta só as entradas activas das entidades curáveis" do
    create(:test_type, loinc_code: "718-7")
    create(:test_type, loinc_code: nil)
    create(:test_type, :draft, loinc_code: nil)
    create(:department, loinc_code: nil)

    coverage = described_class.new

    expect(coverage.total).to eq(2)
    expect(coverage.covered).to eq(1)
    expect(coverage.percentage).to eq(50)
  end

  it "dá a lista do que falta, que é o trabalho em si" do
    create(:test_type, name: "Glicemia", loinc_code: nil)
    create(:test_type, name: "Hemoglobina", loinc_code: "718-7")

    names = described_class.new.uncovered.map { |_, entry| entry.name }

    expect(names).to eq([ "Glicemia" ])
  end
end
