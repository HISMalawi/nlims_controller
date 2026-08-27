# frozen_string_literal: true

require "rails_helper"

# The outbox is a local node's queue: the national node receives events and
# produces none, so there is nothing here for it to do.
RSpec.describe OutboxEvent, mode: :local do
  def types_for(order)
    described_class.where(aggregate_uuid: order.uuid).in_order.pluck(:type)
  end

  describe "what a sample produces" do
    it "records the order as created, carrying the whole thing" do
      order = create(:order)

      event = described_class.where(aggregate_uuid: order.uuid).sole
      expect(event.type).to eq(described_class::ORDER_CREATED)
      expect(event.sequence).to eq(1)
      expect(event.payload.dig("order", "tracking_number")).to eq(order.tracking_number)
      expect(event.payload.dig("order", "patient", "name")).to eq(order.patient.name)
    end

    it "records each transition, with who moved it and why" do
      order = create(:order)
      order.transition_to!(Order::ACCEPTED, actor: "tec.mabjaia", reason: "amostra recebida")

      event = described_class.where(aggregate_uuid: order.uuid).in_order.last
      expect(event.type).to eq(described_class::ORDER_STATUS_CHANGED)
      expect(event.payload).to include(
        "from_status" => Order::REQUESTED,
        "to_status" => Order::ACCEPTED,
        "actor" => "tec.mabjaia",
        "reason" => "amostra recebida"
      )
    end

    it "records a test added to the sample, and its transitions" do
      order = create(:order)
      order_test = create(:order_test, order: order)
      order_test.transition_to!(OrderTest::IN_PROGRESS)

      expect(types_for(order)).to eq([
                                       described_class::ORDER_CREATED,
                                       described_class::ORDER_TEST_ADDED,
                                       described_class::TEST_STATUS_CHANGED
                                     ])
    end

    it "records a reading, and what it supersedes" do
      order_test = create(:order_test)
      indicator = create(:indicator)
      wrong = TestResult.record!(order_test: order_test, indicator: indicator, value: "12.4")
      TestResult.record!(order_test: order_test, indicator: indicator, value: "14.2")

      events = described_class.where(type: described_class::TEST_RESULT_RECORDED).in_order
      expect(events.length).to eq(2)
      expect(events.first.payload["replaces"]).to eq([])
      expect(events.last.payload["replaces"]).to eq([ wrong.uuid ])
      expect(events.last.payload["value"]).to eq("14.2")
    end

    # A rejection reported as a status change would say the sample was refused
    # without saying why, and the why is the most useful thing the laboratory
    # ever tells the rest of the system.
    it "reports a rejection as a rejection, with the reason" do
      order = create(:order)
      order.claim!(lab_code: "HCM-LAB")
      reason = create(:rejection_reason, name: "Amostra hemolisada")
      order.reject!(reason: reason, actor: "tec.mabjaia")

      rejection = described_class.where(type: described_class::SPECIMEN_REJECTED).sole
      expect(rejection.payload.dig("rejection_reason", "national_code")).to eq(reason.national_code)
      expect(rejection.payload["to_status"]).to eq(Order::REJECTED)
    end

    it "records a patient whose details were corrected" do
      patient = create(:patient, :identified, name: "Ana M.")
      described_class.delete_all

      patient.update!(name: "Ana Macuácua")

      event = described_class.sole
      expect(event.type).to eq(described_class::PATIENT_UPSERTED)
      expect(event.payload["name"]).to eq("Ana Macuácua")
    end

    it "says nothing when a save changed nothing a reader would notice" do
      patient = create(:patient)
      described_class.delete_all

      patient.touch

      expect(described_class.count).to be_zero
    end
  end

  describe "ordering" do
    # Per aggregate rather than global, so one sample stuck behind a bad event
    # never holds up another facility's work.
    it "numbers each sample from one, independently of the others" do
      first = create(:order)
      second = create(:order)
      first.transition_to!(Order::ACCEPTED)

      expect(described_class.where(aggregate_uuid: first.uuid).pluck(:sequence)).to eq([ 1, 2 ])
      expect(described_class.where(aggregate_uuid: second.uuid).pluck(:sequence)).to eq([ 1 ])
    end

    it "keeps everything about one sample under the order's uuid, tests included" do
      order = create(:order)
      order_test = create(:order_test, order: order)
      TestResult.record!(order_test: order_test, indicator: create(:indicator), value: "12.4")

      expect(described_class.where(aggregate_uuid: order.uuid).count).to eq(3)
    end

    it "refuses to hand the same sequence to one aggregate twice" do
      order = create(:order)

      expect do
        described_class.create!(event_uuid: SecureRandom.uuid, aggregate_uuid: order.uuid,
                                sequence: 1, type: described_class::ORDER_CREATED,
                                payload: {}, occurred_at: Time.current)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "delivery bookkeeping" do
    let(:event) { create(:order) && described_class.first }

    it "starts out ready to be sent" do
      expect(described_class.ready).to include(event)
      expect(event).not_to be_delivered
    end

    it "leaves the queue once delivered, and stays as evidence" do
      event.mark_delivered!

      expect(described_class.ready).not_to include(event)
      expect(described_class.pending).not_to include(event)
      expect(described_class.exists?(event.id)).to be(true)
    end

    it "waits longer after each failure" do
      event.mark_failed!("national node unreachable")
      first_wait = event.next_attempt_at

      event.mark_failed!("national node unreachable")

      expect(event.attempts).to eq(2)
      expect(event.next_attempt_at).to be > first_wait
      expect(event.last_error).to include("unreachable")
    end

    it "stays out of the queue until its next attempt is due" do
      event.mark_failed!("boom")

      expect(described_class.ready).not_to include(event)
      expect(described_class.ready(1.hour.from_now)).to include(event)
    end

    # For the operator who has fixed whatever the national node was complaining
    # about and does not want to wait out the backoff.
    it "can be put back at the front of the queue by hand" do
      event.mark_failed!("boom")

      event.retry_now!

      expect(described_class.ready).to include(event)
      expect(event.last_error).to be_nil
    end

    # The instant is pinned rather than read twice: the method reads the clock
    # inside and the expectation read it again outside, so a tick between the
    # two put the answer past the bound and failed the run at random.
    it "caps how long it will ever wait" do
      now = Time.current

      expect(described_class::Backoff.next_attempt_at(50, now: now))
        .to be <= (now + described_class::Backoff::MAX + (described_class::Backoff::MAX / 4))
    end
  end

  describe "on a national node" do
    # The national node receives events; it does not produce them. Writing an
    # outbox there would fill a queue that nothing ever drains.
    it "writes nothing" do
      allow(SislabSync).to receive(:local?).and_return(false)

      expect { create(:order) }.not_to change(described_class, :count)
    end
  end
end
