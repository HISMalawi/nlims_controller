# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dictionary::Seed do
  def seed(**options)
    described_class.new(source: MlabFixtureSource.load, actor: "spec", **options).call
  end

  describe "standing a national node up" do
    it "publishes the whole catalogue, because a draft reaches no laboratory" do
      seed

      expect(TestType.active.count).to eq(3)
      expect(Dictionary.models.sum { |model| model.drafts.count }).to eq(0)
    end

    it "adds the rejection reasons mLab keeps no table of" do
      seed

      expect(RejectionReason.active.pluck(:name)).to match_array(described_class::REJECTION_REASONS)
    end

    it "records who published each entry, the way any other promotion does" do
      seed

      change = DictionaryStatusChange.find_by(entity_uuid: TestType.find_by(name: "Urina II").uuid,
                                              to_status: DictionaryEntry::ACTIVE)
      expect(change.actor).to eq("spec")
    end

    it "holds back a test a laboratory could not use, when asked to" do
      result = seed(skip_blocked: true)

      # The fixture carries the two shapes a laboratory cannot work with: one
      # test with no indicators and one with no specimen type.
      expect(TestType.find_by(name: "Cultura de sangue")).to be_draft
      expect(result.promotion.held_back["test_types"]).to eq(2)
    end
  end

  describe "running it again" do
    it "changes nothing the first run did" do
      seed
      revisions = TestType.order(:id).pluck(:revision)

      result = seed

      expect(TestType.count).to eq(3)
      expect(TestType.order(:id).pluck(:revision)).to eq(revisions)
      expect(result.promotion.summary).to eq("  nada para promover")
      expect(result.reasons_created).to eq(0)
    end
  end

  describe "the catalogue shipped with the release" do
    it "stands a node up with the whole of mLab published" do
      result = described_class.new(actor: "spec").call
      catalogue = Dictionary::SnapshotSource.load

      expect(TestType.active.count).to eq(catalogue.test_types.length)
      expect(TestPanel.active.count).to eq(catalogue.test_panels.length)
      expect(Dictionary.models.sum { |model| model.drafts.count }).to eq(0)
      expect(result.published).to eq(Dictionary.models.sum { |model| model.active.count })
    end
  end
end
