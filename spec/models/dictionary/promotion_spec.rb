# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dictionary::Promotion do
  def promote(**options)
    described_class.new(actor: "Kelven", **options).call
  end

  it "publishes drafts so they start travelling down the delta" do
    test_type = create(:test_type, :draft)

    promote

    expect(test_type.reload).to be_active
    expect(Dictionary.changes_since(0).map(&:last)).to include(test_type)
  end

  it "records who published each entry" do
    test_type = create(:test_type, :draft)

    promote

    change = DictionaryStatusChange.for_entity(test_type.uuid).last
    expect(change.actor).to eq("Kelven")
    expect(change.from_status).to eq("draft")
    expect(change.to_status).to eq("active")
  end

  it "counts what it published" do
    create_list(:test_type, 2, :draft)
    create(:specimen_type, :draft)

    result = promote

    expect(result.promoted["test_types"]).to eq(2)
    expect(result.promoted["specimen_types"]).to eq(1)
  end

  it "leaves what is already published alone" do
    test_type = create(:test_type)

    expect { promote }.not_to change { test_type.reload.revision }
  end

  it "does not resurrect a retired entry" do
    test_type = create(:test_type)
    test_type.retire!

    promote

    expect(test_type.reload).to be_retired
  end

  it "can be narrowed to one entity type" do
    test_type = create(:test_type, :draft)
    specimen_type = create(:specimen_type, :draft)

    promote(entities: %w[specimen_types])

    expect(specimen_type.reload).to be_active
    expect(test_type.reload).to be_draft
  end

  describe "holding back what a laboratory cannot use" do
    let!(:complete) do
      test_type = create(:test_type, :draft)
      test_type.indicators << create(:indicator)
      test_type.specimen_types << create(:specimen_type)
      test_type
    end

    let!(:no_indicators) do
      test_type = create(:test_type, :draft)
      test_type.specimen_types << create(:specimen_type)
      test_type
    end

    let!(:no_specimen) do
      test_type = create(:test_type, :draft)
      test_type.indicators << create(:indicator)
      test_type
    end

    it "publishes everything when nothing is held back" do
      promote

      expect([ complete, no_indicators, no_specimen ].map { |entry| entry.reload.status })
        .to all(eq("active"))
    end

    # A test with no indicators cannot carry a result, and one with no specimen
    # cannot be collected. Publishing them puts unusable tests in front of a
    # clinician.
    it "holds back the unusable tests when asked" do
      result = promote(skip_blocked: true)

      expect(complete.reload).to be_active
      expect(no_indicators.reload).to be_draft
      expect(no_specimen.reload).to be_draft
      expect(result.held_back["test_types"]).to eq(2)
      expect(result.promoted["test_types"]).to eq(1)
    end

    it "still publishes the other entity types" do
      specimen_type = create(:specimen_type, :draft)

      promote(skip_blocked: true)

      expect(specimen_type.reload).to be_active
    end
  end
end
