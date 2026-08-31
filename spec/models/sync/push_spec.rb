# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sync::Push, mode: :local do
  let(:national) { RecordingNationalNode.new }

  def push(**options)
    described_class.new(transport: national, node_code: "HCM", **options).call
  end

  it "sends what is waiting and marks it delivered" do
    create(:order)

    result = push

    expect(national.event_uuids).to match_array(OutboxEvent.pluck(:event_uuid))
    expect(OutboxEvent.pending).to be_empty
    expect(result.delivered).to eq(OutboxEvent.count)
  end

  it "sends the node's own code with the batch" do
    create(:order)

    push

    expect(national.heartbeats).to be_empty
    expect(OutboxEvent.delivered.count).to be_positive
  end

  it "sends everything a sample produced, oldest first" do
    order = create(:order)
    order.transition_to!(Order::ACCEPTED)

    push

    expect(national.event_uuids).to eq(OutboxEvent.order(:id).pluck(:event_uuid))
  end

  it "pages a queue larger than one batch" do
    create_list(:order, 5)

    push(batch_size: 2)

    expect(OutboxEvent.pending).to be_empty
    expect(national.batches.length).to be > 1
  end

  it "sends nothing, and asks nothing, when the outbox is empty" do
    expect(push.delivered).to be_zero
    expect(national.batches).to be_empty
  end

  describe "when the national node refuses an event" do
    it "keeps it, with the reason it was given" do
      create(:order)
      refused = OutboxEvent.first
      national = RecordingNationalNode.new(refuse: { refused.event_uuid => "unknown_dictionary_item" })

      described_class.new(transport: national, node_code: "HCM").call

      expect(refused.reload).not_to be_delivered
      expect(refused.last_error).to include("unknown_dictionary_item")
      expect(refused.attempts).to eq(1)
    end

    # A refusal usually means an administrator has to reconcile something, so
    # the event waits out a growing backoff rather than hammering.
    it "waits before trying again" do
      create(:order)
      refused = OutboxEvent.first
      national = RecordingNationalNode.new(refuse: { refused.event_uuid => "unknown_dictionary_item" })

      described_class.new(transport: national, node_code: "HCM").call

      expect(refused.reload.next_attempt_at).to be > Time.current
      expect(OutboxEvent.ready).not_to include(refused)
    end
  end

  describe "when the link is down" do
    it "leaves everything in the queue and says so" do
      create(:order)
      national.offline!

      expect { push }.to raise_error(NodeTransport::TransportError)

      expect(OutboxEvent.pending.count).to eq(OutboxEvent.count)
      expect(OutboxEvent.first.last_error).to include("unreachable")
    end

    it "backs off further with each failed run" do
      create(:order)
      national.offline!
      event = OutboxEvent.first

      2.times do
        event.update_column(:next_attempt_at, nil)
        suppress(NodeTransport::TransportError) { push }
      end

      expect(event.reload.attempts).to eq(2)
    end
  end
end
