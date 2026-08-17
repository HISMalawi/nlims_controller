# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sync::Heartbeat, mode: :local do
  let(:national) { RecordingNationalNode.new }

  def beat
    described_class.new(transport: national, node_code: "HCM").call
  end

  it "reports what this node is worried about" do
    create(:order)

    beat

    reported = national.heartbeats.sole
    expect(reported["node_code"]).to eq("HCM")
    expect(reported["version"]).to eq(SislabSync.version)
    expect(reported["outbox_pending"]).to eq(OutboxEvent.count)
    expect(reported["outbox_failing"]).to be_zero
  end

  # An idle node and an unreachable one look identical from the capital
  # otherwise, and telling them apart is the point.
  it "reports even with nothing to send" do
    beat

    expect(national.heartbeats.sole["outbox_pending"]).to be_zero
  end

  it "carries how far its dictionary has got" do
    SyncCursor.for(SyncCursor::DICTIONARY).advance!(1284)

    beat

    expect(national.heartbeats.sole["dictionary_cursor"]).to eq(1284)
  end

  it "carries the most recent thing that went wrong on the way up" do
    create(:order)
    OutboxEvent.first.mark_failed!("national node unreachable")

    beat

    expect(national.heartbeats.sole["last_error"]).to include("unreachable")
    expect(national.heartbeats.sole["outbox_failing"]).to eq(1)
  end

  it "falls back to what went wrong on the way down" do
    SyncCursor.for(SyncCursor::DICTIONARY).record_failure!("dictionary feed timed out")

    beat

    expect(national.heartbeats.sole["last_error"]).to include("timed out")
  end
end
