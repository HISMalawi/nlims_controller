# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sync::Pull, mode: :local do
  let(:test_type) { create(:test_type, name: "Hemograma") }
  let(:specimen_type) { create(:specimen_type, name: "Sangue total") }
  let(:order_uuid) { SecureRandom.uuid }
  let(:order_test_uuid) { SecureRandom.uuid }
  let(:referral_uuid) { SecureRandom.uuid }

  # What the national node is holding for this node: a sample referred to it.
  def dispatch(revision: 1, to_lab_code: SislabSync.lab_code)
    {
      "revision" => revision, "node_code" => "XAI", "event_uuid" => SecureRandom.uuid,
      "aggregate_uuid" => order_uuid, "sequence" => 1,
      "type" => OutboxEvent::REFERRAL_DISPATCHED, "occurred_at" => Time.current.iso8601,
      "payload" => {
        "referral" => { "uuid" => referral_uuid, "tracking_number" => "MZ-XAI-26229-0001",
                        "state" => "dispatched", "from_facility_code" => "XAI", "from_lab_code" => "XAI-LAB",
                        "to_facility_code" => "HCM", "to_lab_code" => to_lab_code,
                        "dispatched_at" => Time.current.iso8601 },
        "order" => {
          "uuid" => order_uuid, "tracking_number" => "MZ-XAI-26229-0001", "status" => "referred_out",
          "priority" => "routine", "sending_facility_code" => "XAI", "receiving_lab_code" => "XAI-LAB",
          "specimen_type" => { "national_code" => specimen_type.national_code },
          "patient" => { "uuid" => SecureRandom.uuid, "name" => "Ana Macuácua", "sex" => "F" },
          "tests" => [ { "uuid" => order_test_uuid, "status" => "in_progress",
                         "test_type" => { "national_code" => test_type.national_code } } ]
        }
      }
    }
  end

  def feed(*events)
    RecordedInbound.new(events)
  end

  def pull(transport)
    described_class.new(transport: transport, node_code: SislabSync.node_code).call
  end

  it "takes in a sample referred here, as work arriving" do
    pull(feed(dispatch))

    order = Order.find_by!(uuid: order_uuid)
    expect(order.status).to eq(Order::REFERRED_IN)
    expect(order.tracking_number).to eq("MZ-XAI-26229-0001")
    expect(order.patient.name).to eq("Ana Macuácua")
  end

  # The node receiving it was not there when the tests were added and will
  # never be sent those events: they happened before it had anything to do
  # with the sample.
  it "brings the tests with the sample" do
    pull(feed(dispatch))

    expect(Order.find_by!(uuid: order_uuid).order_tests.sole.test_type).to eq(test_type)
  end

  it "records the referral, so the laboratory can see where the sample came from" do
    pull(feed(dispatch))

    referral = Referral.find_by!(uuid: referral_uuid)
    expect(referral.from_facility_code).to eq("XAI")
    expect(referral).to be_dispatched
  end

  # A sample merely passing through — this node is the origin hearing news about
  # a sample it sent elsewhere — is not work arriving here.
  it "leaves a sample referred somewhere else as it was sent" do
    pull(feed(dispatch(to_lab_code: "MAP-LAB-CENTRAL")))

    expect(Order.find_by!(uuid: order_uuid).status).to eq(Order::REFERRED_OUT)
  end

  # Without this the two nodes holding one referred sample would send each
  # other's events back and forth for ever.
  it "produces no events of its own from what it applied" do
    expect { pull(feed(dispatch)) }.not_to change(OutboxEvent, :count)
  end

  it "leaves the outbox working normally afterwards" do
    pull(feed(dispatch))

    expect { create(:order) }.to change(OutboxEvent, :count)
  end

  it "moves its cursor only as far as it has applied" do
    transport = feed(dispatch)

    pull(transport)

    expect(SyncCursor.value_for(SyncCursor::INBOUND)).to eq(1)
    expect(SyncCursor.for(SyncCursor::INBOUND)).to be_healthy
  end

  it "asks for nothing it has already taken" do
    transport = feed(dispatch)

    pull(transport)
    pull(transport)

    expect(Order.where(uuid: order_uuid).count).to eq(1)
    expect(transport.requests.last).to eq(1)
  end

  it "keeps each origin's stream in its own order" do
    from_xai = dispatch(revision: 1)
    from_map = dispatch(revision: 2).merge(
      "node_code" => "MAP", "event_uuid" => SecureRandom.uuid, "aggregate_uuid" => SecureRandom.uuid
    )

    pull(feed(from_xai, from_map))

    expect(InboundEvent.pluck(:node_code)).to contain_exactly("XAI", "MAP")
    expect(InboundEvent.applied.count).to eq(2)
  end

  it "records what went wrong on the cursor rather than swallowing it" do
    expect { pull(BrokenInbound.new) }.to raise_error(NodeTransport::TransportError)

    cursor = SyncCursor.for(SyncCursor::INBOUND)
    expect(cursor).not_to be_healthy
    expect(cursor.last_error).to include("unreachable")
  end
end
