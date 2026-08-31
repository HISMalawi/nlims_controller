# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dictionary::Serializer do
  describe "a test type" do
    subject(:payload) { described_class.call("test_types", test_type) }

    let(:department) { create(:department, name: "Bioquímica", moh_code: "BIO") }
    let(:specimen_type) { create(:specimen_type) }
    let(:indicator) { create(:indicator) }

    let(:test_type) do
      test_type = create(:test_type, name: "Hemograma", short_name: "HC",
                                     department: department, target_tat: "4 horas")
      test_type.specimen_types << specimen_type
      test_type.indicators << indicator
      test_type.reload
    end

    it "carries the identity and the revision" do
      expect(payload).to include(
        entity: "test_types",
        uuid: test_type.uuid,
        national_code: test_type.national_code,
        revision: test_type.reload.revision,
        status: "active",
        name: "Hemograma",
        short_name: "HC"
      )
    end

    # An id means nothing on the other side, and after a re-seed it would point
    # at a different record without anything looking wrong.
    it "addresses everything by national code and never by id" do
      expect(payload[:department]).to eq({ national_code: department.national_code })
      expect(payload[:specimen_types]).to eq([ { national_code: specimen_type.national_code } ])
      expect(payload[:indicators]).to eq([ { national_code: indicator.national_code } ])
      expect(payload.to_json).not_to include(%("id":))
    end

    it "orders links so an unchanged entry serialises identically each time" do
      second = create(:specimen_type)
      third = create(:specimen_type)
      test_type.specimen_types << [ third, second ]

      codes = described_class.call("test_types", test_type.reload)[:specimen_types].pluck(:national_code)

      expect(codes).to eq(codes.sort)
    end

    it "omits a section it does not have" do
      test_type.update!(department: nil)

      expect(described_class.call("test_types", test_type)[:department]).to be_nil
    end
  end

  describe "an indicator" do
    let(:indicator) { create(:indicator, unit: "g/dL", value_type: "Numeric") }

    it "ships its reference intervals inline" do
      create(:indicator_range, indicator: indicator, sex: "M", range_lower: 13, range_upper: 17)

      payload = described_class.call("indicators", indicator.reload)

      expect(payload[:unit]).to eq("g/dL")
      expect(payload[:value_type]).to eq("Numeric")
      expect(payload[:ranges].first).to include(sex: "M", age_min: 0, age_max: 120)
    end

    # Read back as a float and written again, a reference interval drifts — and a
    # drifting interval changes how a result reads.
    it "sends interval bounds as strings" do
      create(:indicator_range, indicator: indicator, range_lower: 12.5, range_upper: 16.25)

      range = described_class.call("indicators", indicator.reload)[:ranges].first

      expect(range[:range_lower]).to eq("12.5")
      expect(range[:range_upper]).to eq("16.25")
    end
  end

  describe "a retired entry" do
    it "says so, and carries when it happened" do
      test_type = create(:test_type)
      test_type.retire!

      payload = described_class.call("test_types", test_type)

      expect(payload[:status]).to eq("retired")
      expect(payload[:deleted_at]).to be_present
    end
  end
end
