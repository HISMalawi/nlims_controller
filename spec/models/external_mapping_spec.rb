# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExternalMapping do
  let(:test_type) { create(:test_type) }

  it "points at a dictionary entry by uuid" do
    mapping = create(:external_mapping, entity_type: "test_types", entity_uuid: test_type.uuid)

    expect(mapping.entity).to eq(test_type)
  end

  it "refuses a system it does not know" do
    expect { create(:external_mapping, system: "openmrs") }
      .to raise_error(ActiveRecord::RecordInvalid, /System/)
  end

  it "refuses the same external code twice for one system and entity type" do
    create(:external_mapping, system: "mlab", entity_type: "test_types", external_code: "HB")

    expect { create(:external_mapping, system: "mlab", entity_type: "test_types", external_code: "HB") }
      .to raise_error(ActiveRecord::RecordInvalid, /External code/)
  end

  it "allows the same code for a different entity type" do
    create(:external_mapping, system: "mlab", entity_type: "test_types", external_code: "HB")

    expect(create(:external_mapping, system: "mlab", entity_type: "specimen_types", external_code: "HB"))
      .to be_persisted
  end

  describe ".resolve" do
    it "translates a client code into the national uuid" do
      create(:external_mapping, system: "mlab", entity_type: "test_types",
                                external_code: "HB", entity_uuid: test_type.uuid)

      expect(described_class.resolve(system: "mlab", entity_type: "test_types", external_code: "HB"))
        .to eq(test_type.uuid)
    end

    # One laboratory's local naming must not become everybody's.
    it "prefers a mapping registered for the calling client over the system-wide one" do
      client = create(:api_client, :sislab)
      other_test_type = create(:test_type)

      create(:external_mapping, system: "mlab", entity_type: "test_types",
                                external_code: "HB", entity_uuid: test_type.uuid)
      create(:external_mapping, system: "mlab", entity_type: "test_types", api_client: client,
                                external_code: "HB", entity_uuid: other_test_type.uuid)

      expect(described_class.resolve(system: "mlab", entity_type: "test_types",
                                     external_code: "HB", api_client: client))
        .to eq(other_test_type.uuid)
    end

    it "falls back to the system-wide mapping when the client has none" do
      client = create(:api_client, :sislab)
      create(:external_mapping, system: "mlab", entity_type: "test_types",
                                external_code: "HB", entity_uuid: test_type.uuid)

      expect(described_class.resolve(system: "mlab", entity_type: "test_types",
                                     external_code: "HB", api_client: client))
        .to eq(test_type.uuid)
    end

    it "is nil for a code nobody has mapped" do
      expect(described_class.resolve(system: "mlab", entity_type: "test_types", external_code: "NADA"))
        .to be_nil
    end
  end
end
