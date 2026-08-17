# frozen_string_literal: true

require "rails_helper"

RSpec.describe Patient do
  it "gets a uuid that crosses node boundaries" do
    expect(create(:patient).uuid).to be_present
  end

  it "requires a name and a sex it knows" do
    patient = build(:patient, name: nil, sex: "outro")

    expect(patient).not_to be_valid
    expect(patient.errors.attribute_names).to include(:name, :sex)
  end

  it "refuses a birthdate in the future" do
    expect(build(:patient, birthdate: Date.current + 1)).not_to be_valid
  end

  describe "the national identifier" do
    # The whole point of the NID is that the same person arriving from two
    # facilities becomes one patient. Two patients holding it would undo that.
    it "belongs to one patient" do
      create(:patient, national_id: "110100234567A")

      expect(build(:patient, national_id: "110100234567A")).not_to be_valid
    end

    # A great many patients arrive without one, and inventing a placeholder is
    # how the current system ends up with a hundred patients called "S/N".
    it "may be absent on any number of patients" do
      create_list(:patient, 2, national_id: nil)

      expect(described_class.where(national_id: nil).count).to eq(2)
      expect(described_class.identified).to be_empty
    end

    it "is stored the way it will be searched for" do
      patient = create(:patient, national_id: "  110100234567a ")

      expect(patient.national_id).to eq("110100234567A")
    end

    it "treats an empty identifier as no identifier" do
      expect(create(:patient, national_id: "  ").national_id).to be_nil
    end
  end
end
