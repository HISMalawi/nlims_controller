# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dictionary::Puller do
  def wipe_dictionary!
    DictionaryLinkDeferral.delete_all
    [ TestTypeSpecimenType, TestTypeIndicator, TestTypeOrganism, TestPanelTestType,
      OrganismDrug, IndicatorRange ].each(&:delete_all)
    Dictionary.models.reverse.each(&:delete_all)
    DictionaryStatusChange.delete_all
  end

  let!(:entries) do
    Dictionary::MlabImporter.new(source: MlabFixtureSource.load).call
    Dictionary::Promotion.new(actor: "spec").call
    payload = Dictionary.delta(0)[:entries]
    wipe_dictionary!
    payload
  end

  let(:feed) { RecordedFeed.new(entries) }

  def cursor
    SyncCursor.for(SyncCursor::DICTIONARY)
  end

  describe "a first pull" do
    it "brings the whole dictionary down" do
      described_class.new(transport: feed).call

      expect(Dictionary.models.sum(&:count)).to eq(entries.length)
    end

    it "walks the feed in batches until it is drained" do
      puller = described_class.new(transport: feed, limit: 4).call

      expect(puller.batches).to be > 1
      expect(Dictionary.models.sum(&:count)).to eq(entries.length)
    end

    it "leaves the cursor at the last revision it applied" do
      described_class.new(transport: feed).call

      expect(cursor.value).to eq(entries.map { |entry| entry[:revision] }.max)
      expect(cursor.last_synced_at).to be_present
      expect(cursor).to be_healthy
    end
  end

  describe "resuming" do
    # The cursor is persisted precisely so a node that died mid-sync does not
    # start over, and so a five-minute schedule is cheap when nothing changed.
    it "asks only for what it has not seen" do
      halfway = entries.map { |entry| entry[:revision] }.sort[4]
      cursor.update!(value: halfway)

      described_class.new(transport: feed).call

      expect(feed.requests.first).to eq(halfway)
      expect(Dictionary.models.sum(&:count)).to eq(entries.count { |entry| entry[:revision] > halfway })
    end

    it "does nothing but mark itself synced when there is nothing new" do
      described_class.new(transport: feed).call
      settled = cursor.value

      described_class.new(transport: RecordedFeed.new(entries)).call

      expect(cursor.value).to eq(settled)
      expect(cursor.last_synced_at).to be_present
    end

    it "survives being restarted between batches" do
      described_class.new(transport: RecordedFeed.new(entries), limit: 3).call
      first_pass = Dictionary.models.sum(&:count)

      # A fresh puller, as a restarted process would build.
      described_class.new(transport: RecordedFeed.new(entries), limit: 3).call

      expect(Dictionary.models.sum(&:count)).to eq(first_pass)
      expect(first_pass).to eq(entries.length)
    end
  end

  describe "when the national node cannot be reached" do
    it "records the failure on the cursor and lets the error through" do
      expect { described_class.new(transport: BrokenFeed.new).call }
        .to raise_error(described_class::TransportError)

      expect(cursor.last_error).to include("unreachable")
      expect(cursor.consecutive_failures).to eq(1)
      expect(cursor).not_to be_healthy
    end

    it "keeps the cursor where it was, so nothing is skipped" do
      described_class.new(transport: feed).call
      settled = cursor.value

      expect { described_class.new(transport: BrokenFeed.new).call }.to raise_error(described_class::TransportError)

      expect(cursor.value).to eq(settled)
    end

    it "counts repeated failures so a stuck node is visible" do
      2.times do
        described_class.new(transport: BrokenFeed.new).call
      rescue described_class::TransportError
        nil
      end

      expect(cursor.consecutive_failures).to eq(2)
    end

    it "clears the failure once it gets through again" do
      begin
        described_class.new(transport: BrokenFeed.new).call
      rescue described_class::TransportError
        nil
      end

      described_class.new(transport: feed).call

      expect(cursor).to be_healthy
      expect(cursor.last_error).to be_nil
    end
  end

  describe "a feed that never says it is done" do
    it "stops itself instead of spinning" do
      stub_const("Dictionary::Puller::MAX_BATCHES", 3)

      puller = described_class.new(transport: EndlessFeed.new).call

      expect(puller.batches).to eq(3)
    end
  end

  describe "#summary" do
    it "says what it did" do
      puller = described_class.new(transport: feed).call

      expect(puller.summary).to include("test_types=3", "batches=")
    end
  end
end
