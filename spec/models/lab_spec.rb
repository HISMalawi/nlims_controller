# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lab do
  it "is a dictionary entity, so it travels on the feed with everything else" do
    expect(Dictionary::ENTITIES).to include("labs" => "Lab")

    lab = create(:lab, name: "Laboratório Central de Maputo")

    expect(lab.national_code).to start_with("MOZ-LAB-")
    expect(Dictionary.model_for!("labs")).to eq(described_class)
  end

  # What the register exists for: a node that has it can address a parcel to
  # another laboratory without anybody typing in a health facility code.
  it "carries where the laboratory is" do
    lab = create(:lab, facility_code: "HCM", facility_name: "Hospital Central de Maputo",
                       district: "KaMpfumo", province: "Maputo Cidade")

    expect(lab.facility).to eq("HCM")
    expect(lab.place).to eq("KaMpfumo, Maputo Cidade")
  end

  # An entry the capital has not filled in completely is still usable: the
  # laboratory's own code stands in, so nothing downstream is left blank.
  it "falls back to its own code when it has no facility" do
    expect(create(:lab, facility_code: nil).facility).to match(/\AMOZ-LAB-/)
  end

  describe ".this_node", mode: :local do
    it "finds the entry this node answers to" do
      lab = create(:lab, national_code: SislabSync.lab_code)

      expect(described_class.this_node).to eq(lab)
    end

    it "is nil before the register has reached this node" do
      expect(described_class.this_node).to be_nil
    end
  end

  describe "on the feed" do
    it "ships where the laboratory is, so the receiving node can route to it" do
      lab = create(:lab, national_code: "MAP-LAB", name: "Laboratório Central de Maputo",
                         facility_code: "MAP", district: "KaMpfumo", province: "Maputo Cidade")

      entry = Dictionary::Serializer.call("labs", lab)

      expect(entry).to include(entity: "labs", national_code: "MAP-LAB", facility_code: "MAP",
                               district: "KaMpfumo", province: "Maputo Cidade")
    end

    it "is applied on the receiving node with its whereabouts intact" do
      entry = Dictionary::Serializer.call("labs", create(:lab, national_code: "MAP-LAB", facility_code: "MAP"))
      described_class.delete_all

      Dictionary::Applier.new.apply([ entry.deep_stringify_keys ])

      applied = described_class.find_by!(national_code: "MAP-LAB")
      expect(applied.facility_code).to eq("MAP")
      expect(applied).to be_active
    end
  end
end
