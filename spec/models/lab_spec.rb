# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lab do
  it "is a dictionary entity, so it travels on the feed with everything else" do
    expect(Dictionary::ENTITIES).to include("labs" => "Lab")
    expect(Dictionary.model_for!("labs")).to eq(described_class)
  end

  # Only in the capital. A local node registers laboratories without a code and
  # waits to be told, which is what the rest of this file is about.
  it "takes a national code where national codes are issued", mode: :national do
    expect(described_class.new(name: "Laboratório Central").tap(&:save!).national_code)
      .to start_with("MOZ-LAB-")
  end

  # What the register exists for: a node that has it can address a parcel to
  # another laboratory without anybody typing in a health facility code.
  it "points at the health facility it sits in" do
    facility = create(:facility, national_code: "HCM", name: "Hospital Central de Maputo",
                                 district: "KaMpfumo", province: "Maputo Cidade")
    lab = create(:lab, facility_code: "HCM")

    expect(lab.facility).to eq(facility)
    expect(lab.place).to eq("KaMpfumo, Maputo Cidade")
  end

  describe "a laboratory a node registered itself" do
    # The capital issues national codes. A node that issued its own would sooner
    # or later issue one the country had already given to somebody else.
    it "is created without a national code", mode: :local do
      lab = described_class.register_local!(source_code: "LAB01", facility_code: "HCM",
                                            name: "Laboratório de Bioquímica")

      expect(lab.national_code).to be_nil
      expect(lab).to be_local
      expect(lab.code).to eq("LAB01")
    end

    it "is registered once, however many samples arrive from it", mode: :local do
      first = described_class.register_local!(source_code: "LAB01", facility_code: "HCM", name: "Bioquímica")
      again = described_class.register_local!(source_code: "LAB01", facility_code: "HCM", name: "Bioquímica")

      expect(again).to eq(first)
      expect(described_class.where(source_code: "LAB01").count).to eq(1)
    end

    # An mLab code means nothing outside the instance that issued it, so two
    # units may both call a laboratory LAB01 and mean different places.
    it "does not collide with the same code in another unit", mode: :local do
      here = described_class.register_local!(source_code: "LAB01", facility_code: "HCM", name: "Bioquímica")
      there = described_class.register_local!(source_code: "LAB01", facility_code: "HPM", name: "Bioquímica")

      expect(there).not_to eq(here)
    end

    # This is what carries it to the capital, which is the only place a national
    # code comes from.
    it "announces itself upwards", mode: :local do
      lab = described_class.register_local!(source_code: "LAB01", facility_code: "HCM", name: "Bioquímica")

      event = OutboxEvent.find_by(type: OutboxEvent::LAB_REGISTERED, aggregate_uuid: lab.uuid)

      expect(event).to be_present
      expect(event.payload).to include("source_code" => "LAB01", "facility_code" => "HCM")
    end

    # Otherwise the country would register each of its laboratories once per
    # node that had heard of it.
    it "does not announce the capital's own entry back to it", mode: :local do
      entry = Dictionary::Serializer.call("labs", create(:lab, national_code: "MOZ-LAB-9999"))
      described_class.delete_all
      OutboxEvent.delete_all

      Dictionary::Applier.new.apply([ entry.deep_stringify_keys ])

      expect(OutboxEvent.where(type: OutboxEvent::LAB_REGISTERED)).to be_empty
    end
  end

  describe ".find_by_any_code" do
    it "answers to a national code" do
      lab = create(:lab, national_code: "MOZ-LAB-0001")

      expect(described_class.find_by_any_code("MOZ-LAB-0001")).to eq(lab)
    end

    # A bench cannot be told to wait for the capital before the bench next door
    # can hand it a sample.
    it "answers to the LIS code inside its own unit", mode: :local do
      lab = described_class.register_local!(source_code: "LAB01", facility_code: "HCM", name: "Bioquímica")

      expect(described_class.find_by_any_code("LAB01", facility_code: "HCM")).to eq(lab)
      expect(described_class.find_by_any_code("LAB01", facility_code: "HPM")).to be_nil
    end
  end

  describe "on the feed" do
    it "ships the unit and the LIS code, so the receiving node can route to it" do
      lab = create(:lab, national_code: "MAP-LAB", name: "Laboratório Central de Maputo",
                         facility_code: "MAP", source_code: "LAB01")

      entry = Dictionary::Serializer.call("labs", lab)

      expect(entry).to include(entity: "labs", national_code: "MAP-LAB",
                               facility_code: "MAP", source_code: "LAB01")
    end

    it "is applied on the receiving node with its whereabouts intact" do
      entry = Dictionary::Serializer.call("labs", create(:lab, national_code: "MAP-LAB", facility_code: "MAP"))
      described_class.delete_all

      Dictionary::Applier.new.apply([ entry.deep_stringify_keys ])

      applied = described_class.find_by!(national_code: "MAP-LAB")
      expect(applied.facility_code).to eq("MAP")
      expect(applied).to be_active
    end

    # A node that registered a laboratory and was then rebuilt from the feed has
    # lost the uuid it sent up, but not the pair the register is keyed on.
    # Without this the rebuild ends with two rows for one laboratory.
    it "adopts the local row the capital has now named", mode: :local do
      local = described_class.register_local!(source_code: "LAB01", facility_code: "HCM", name: "Bioquímica")

      # The capital's copy: a different uuid, because this node was rebuilt and
      # the one it sent up is gone, but the same unit and the same LIS code.
      entry = {
        "entity" => "labs", "revision" => 900, "uuid" => SecureRandom.uuid,
        "national_code" => "MOZ-LAB-0500", "status" => DictionaryEntry::ACTIVE,
        "name" => "Laboratório de Bioquímica", "facility_code" => "HCM", "source_code" => "LAB01"
      }

      Dictionary::Applier.new.apply([ entry ])

      expect(described_class.where(facility_code: "HCM", source_code: "LAB01").count).to eq(1)
      expect(local.reload.national_code).to eq("MOZ-LAB-0500")
    end
  end
end
