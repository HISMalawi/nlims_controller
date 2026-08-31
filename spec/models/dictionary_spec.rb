# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dictionary do
  describe ".changes_since" do
    it "walks every entity type with one cursor, oldest first" do
      specimen_type = create(:specimen_type)
      test_type = create(:test_type)
      indicator = create(:indicator)

      changes = described_class.changes_since(0)

      expect(changes.map(&:first)).to eq(%w[specimen_types test_types indicators])
      expect(changes.map(&:last)).to eq([ specimen_type, test_type, indicator ])
    end

    it "returns nothing once the cursor has caught up" do
      create(:test_type)

      expect(described_class.changes_since(described_class.cursor)).to be_empty
    end

    it "picks a change up again when its record moves" do
      test_type = create(:test_type)
      cursor = described_class.cursor

      test_type.update!(short_name: "HC")

      expect(described_class.changes_since(cursor).map(&:last)).to eq([ test_type ])
    end

    it "can be narrowed to the entity types a client cares about" do
      create(:specimen_type)
      test_type = create(:test_type)

      changes = described_class.changes_since(0, entities: %w[test_types])

      expect(changes.map(&:last)).to eq([ test_type ])
    end

    it "never leaks a draft" do
      create(:test_type, :draft)
      create(:specimen_type, :draft)

      expect(described_class.changes_since(0)).to be_empty
    end

    it "refuses an entity type that is not part of the dictionary" do
      expect { described_class.changes_since(0, entities: %w[patients]) }
        .to raise_error(described_class::UnknownEntity, /patients/)
    end

    it "stops at the limit, keeping the oldest changes" do
      created = Array.new(4) { create(:test_type) }

      changes = described_class.changes_since(0, limit: 2)

      expect(changes.map(&:last)).to eq(created.first(2))
    end
  end

  describe ".model_for" do
    it "maps an entity type to its model" do
      expect(described_class.model_for("test_types")).to eq(TestType)
    end

    it "is nil for anything else" do
      expect(described_class.model_for("orders")).to be_nil
    end
  end

  describe ".published_counts" do
    it "counts what a local node would end up holding" do
      create(:test_type)
      create(:test_type, :draft)
      create(:test_type).retire!

      expect(described_class.published_counts["test_types"]).to eq(2)
    end
  end
end
