# frozen_string_literal: true

require "rails_helper"

# The one rule the whole façade rests on. The imported catalogue arrived with no
# LOINC codes at all, so a façade that emitted only LOINC would be unusable
# today, and one that emitted only national codes would produce reports nobody
# outside the country could read. Both, in this order, is what makes the
# curation improve the wire format on its own.
RSpec.describe Fhir::CodeableConcept do
  it "puts the national code first, because it is always there" do
    test_type = create(:test_type, name: "Hemoglobina")

    concept = described_class.call(test_type)

    expect(concept[:coding].first).to eq(
      system: Fhir.code_system("test_types"),
      code: test_type.national_code,
      display: "Hemoglobina"
    )
    expect(concept[:text]).to eq("Hemoglobina")
  end

  it "adds LOINC where the dictionary has been curated" do
    test_type = create(:test_type, name: "Hemoglobina", loinc_code: "718-7")

    expect(described_class.call(test_type)[:coding].last)
      .to eq(system: "http://loinc.org", code: "718-7", display: "Hemoglobina")
  end

  # Silence, not a guess. A wrong LOINC code says confidently that a test is
  # something it is not, to every system that reads it.
  it "says nothing about LOINC where nobody has curated it" do
    concept = described_class.call(create(:test_type, loinc_code: nil))

    expect(concept[:coding].length).to eq(1)
    expect(concept[:coding].map { |coding| coding[:system] }).not_to include("http://loinc.org")
  end

  it "names each entity type's own code system" do
    expect(described_class.call(create(:indicator))[:coding].first[:system])
      .to eq(Fhir.code_system("indicators"))
    expect(described_class.call(create(:specimen_type))[:coding].first[:system])
      .to eq(Fhir.code_system("specimen_types"))
  end

  it "is nothing at all for an entry that is not there" do
    expect(described_class.call(nil)).to be_nil
  end
end
