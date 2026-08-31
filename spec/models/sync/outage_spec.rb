# frozen_string_literal: true

require "rails_helper"

# The property the whole outbox exists for: with the national node unreachable
# for an hour of ordinary work, nothing is lost; when it comes back, everything
# goes up in order; and sending the same batch again on purpose changes nothing.
#
# The link between a district laboratory and the capital is down often enough
# that this is the normal case rather than the exceptional one.
RSpec.describe "an outage between a node and the capital", mode: :local, type: :model do
  let(:national) { RecordingNationalNode.new }

  def push
    Sync::Push.new(transport: national, node_code: "HCM").call
  end

  def push_ignoring_outage
    push
  rescue NodeTransport::TransportError
    nil
  end

  # An hour of what a small laboratory actually does: samples arrive, are taken
  # up, are worked on, produce readings, and one of them turns out to be wrong.
  def an_hour_of_work
    reason = create(:rejection_reason, name: "Amostra hemolisada")
    indicator = create(:indicator, name: "Hemoglobina")
    worked, rejected = nil

    travel_to(Time.current) do
      worked = create(:order, receiving_lab_code: "HCM-LAB")
      order_test = create(:order_test, order: worked)

      travel 10.minutes
      worked.claim!(lab_code: "HCM-LAB", actor: "tec.mabjaia")
      worked.transition_to!(Order::SPECIMEN_COLLECTED, actor: "enf.langa")
      worked.transition_to!(Order::IN_PROGRESS, actor: "tec.mabjaia")
      push_ignoring_outage

      travel 20.minutes
      order_test.transition_to!(OrderTest::IN_PROGRESS, actor: "tec.mabjaia")
      TestResult.record!(order_test: order_test, indicator: indicator, value: "12.4",
                         unit: "g/dL", recorded_by: "tec.mabjaia")
      push_ignoring_outage

      travel 20.minutes
      # The reading was wrong; the corrected one has to travel too.
      TestResult.record!(order_test: order_test, indicator: indicator, value: "14.2",
                         unit: "g/dL", recorded_by: "dr.sitoe")
      order_test.transition_to!(OrderTest::COMPLETED, actor: "dr.sitoe")

      rejected = create(:order, receiving_lab_code: "HCM-LAB")
      rejected.claim!(lab_code: "HCM-LAB", actor: "tec.mabjaia")
      rejected.reject!(reason: reason, actor: "tec.mabjaia", note: "recebida 6h depois")
      push_ignoring_outage
    end

    [ worked, rejected ]
  end

  describe "while the link is down" do
    before { national.offline! }

    it "loses nothing: every change is still in the queue" do
      worked, rejected = an_hour_of_work

      expect(national.deliveries).to be_empty
      expect(OutboxEvent.delivered).to be_empty
      expect(OutboxEvent.pending.count).to eq(OutboxEvent.count)

      # Every transition that happened has an event waiting for it.
      expect(OutboxEvent.where(aggregate_uuid: worked.uuid).count)
        .to eq(StatusEvent.for_order(worked.tracking_number).count + worked.test_results.count)
      expect(OutboxEvent.where(aggregate_uuid: rejected.uuid).count).to be_positive
    end

    it "stops hammering: each failure waits longer than the last" do
      an_hour_of_work

      event = OutboxEvent.order(:id).first
      expect(event.attempts).to be > 1
      expect(event.next_attempt_at).to be > Time.current
      expect(event.last_error).to include("unreachable")
    end
  end

  describe "when the link comes back" do
    it "sends everything that happened, exactly once, oldest first" do
      national.offline!
      an_hour_of_work
      national.online!

      travel 1.hour do
        push
      end

      expect(OutboxEvent.pending).to be_empty
      expect(national.event_uuids).to eq(OutboxEvent.order(:id).pluck(:event_uuid))
      expect(national.event_uuids.uniq.length).to eq(national.event_uuids.length)
    end

    it "sends each sample's events in the order they happened" do
      national.offline!
      worked, = an_hour_of_work
      national.online!

      travel(1.hour) { push }

      sequences = national.deliveries
                          .select { |event| event["aggregate_uuid"] == worked.uuid }
                          .map { |event| event["sequence"] }

      expect(sequences).to eq(sequences.sort)
      expect(sequences).to eq((1..sequences.length).to_a)
    end

    it "has nothing left to say on the next run" do
      national.offline!
      an_hour_of_work
      national.online!
      travel(1.hour) { push }

      sent = national.event_uuids.length
      push

      expect(national.event_uuids.length).to eq(sent)
    end
  end

  # The strongest form of the question, and the one two containers would ask:
  # given only what this node sent, can the national node rebuild the sample?
  # The domain rows are cleared first, so the events are all the receiver has.
  describe "replayed into an empty database" do
    it "rebuilds the sample the laboratory worked on" do
      national.offline!
      worked, rejected = an_hour_of_work
      national.online!
      travel(1.hour) { push }

      wire = national.deliveries
      tracking_number = worked.tracking_number
      rejected_tracking_number = rejected.tracking_number

      clear_the_node
      as_the_national_node do
        result = Sync::Ingest.new(node_code: "HCM", events: wire).call

        expect(result.rejected).to be_empty
        expect(result.accepted.length).to eq(wire.length)
      end

      rebuilt = Order.find_by!(tracking_number: tracking_number)
      expect(rebuilt.status).to eq(Order::IN_PROGRESS)
      expect(rebuilt.patient.name).to be_present
      expect(rebuilt.order_tests.sole.status).to eq(OrderTest::COMPLETED)

      # The correction survived the journey, and so did the reading it replaced.
      expect(rebuilt.test_results.count).to eq(2)
      expect(rebuilt.test_results.current.sole.value).to eq("14.2")

      refused = Order.find_by!(tracking_number: rejected_tracking_number)
      expect(refused.status).to eq(Order::REJECTED)
      expect(refused.rejection_reason.name).to eq("Amostra hemolisada")
    end

    # Resending is not an error case; it is what happens whenever an answer is
    # lost on the way back rather than the request on the way out. The far end
    # has to recognise the second copy — that is what makes at-least-once
    # delivery safe to build on.
    it "rebuilds it identically when the same batch is sent again on purpose" do
      national.offline!
      worked, = an_hour_of_work
      national.online!
      travel(1.hour) { push }

      wire = national.deliveries
      tracking_number = worked.tracking_number

      clear_the_node
      as_the_national_node do
        Sync::Ingest.new(node_code: "HCM", events: wire).call
        Sync::Ingest.new(node_code: "HCM", events: wire).call
      end

      expect(Order.where(tracking_number: tracking_number).count).to eq(1)
      expect(Order.find_by!(tracking_number: tracking_number).test_results.count).to eq(2)
      expect(InboundEvent.count).to eq(wire.length)
    end
  end

  # Everything the node knows about samples, so that what comes back can only
  # have come from the events themselves. The dictionary stays: the national
  # node has its own, and it is what the events are addressed against.
  def clear_the_node
    OutboxEvent.delete_all
    TestResult.delete_all
    StatusEvent.delete_all
    OrderTest.delete_all
    Order.delete_all
    Patient.delete_all
  end

  # The receiving side runs as the national node does: it applies events and
  # produces none of its own.
  def as_the_national_node
    allow(SislabSync).to receive(:local?).and_return(false)
    yield
  ensure
    allow(SislabSync).to receive(:local?).and_call_original
  end
end
