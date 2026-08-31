# frozen_string_literal: true

require "rails_helper"

RSpec.describe SyncCursor do
  subject(:cursor) { described_class.for(described_class::DICTIONARY) }

  it "starts at zero" do
    expect(cursor.value).to eq(0)
    expect(described_class.value_for(described_class::DICTIONARY)).to eq(0)
  end

  it "returns the same row when asked twice" do
    first = described_class.for(described_class::DICTIONARY)

    expect(described_class.for(described_class::DICTIONARY)).to eq(first)
    expect(described_class.count).to eq(1)
  end

  describe "#advance!" do
    it "moves forward and records the success" do
      cursor.advance!(120)

      expect(cursor.reload.value).to eq(120)
      expect(cursor.last_synced_at).to be_present
    end

    # A cursor that could go backwards would re-deliver changes for ever, and a
    # stale value arriving out of order must not undo real progress.
    it "never goes backwards" do
      cursor.advance!(120)

      cursor.advance!(50)

      expect(cursor.reload.value).to eq(120)
    end

    it "still marks the node as synced when there was nothing new" do
      cursor.advance!(120)
      cursor.update!(last_synced_at: 1.hour.ago)

      cursor.advance!(120)

      expect(cursor.reload.last_synced_at).to be_within(5.seconds).of(Time.current)
    end
  end

  describe "failures" do
    it "records the error and counts the attempt" do
      cursor.record_failure!("national node unreachable")

      expect(cursor.reload.last_error).to eq("national node unreachable")
      expect(cursor.consecutive_failures).to eq(1)
      expect(cursor).not_to be_healthy
    end

    it "counts consecutive failures so a stuck node shows up" do
      3.times { cursor.record_failure!("boom") }

      expect(cursor.reload.consecutive_failures).to eq(3)
    end

    it "clears once a sync gets through" do
      cursor.record_failure!("boom")

      cursor.advance!(10)

      expect(cursor.reload).to be_healthy
      expect(cursor.last_error).to be_nil
    end

    it "truncates an error too long for the column" do
      cursor.record_failure!("x" * 2000)

      expect(cursor.reload.last_error.length).to be <= 1000
    end
  end
end
