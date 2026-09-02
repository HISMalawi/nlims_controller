# frozen_string_literal: true

require "rails_helper"

# A sample referred from one district to another, followed all the way round:
# the clinic at HCM raises it, HCM's laboratory cannot run the test and sends it
# to MAP, MAP runs it, and the clinic at HCM reads the result under the number
# it was given on the first day.
#
# The plan asks for three containers. This runs the three nodes one at a time in
# one process instead, and each phase begins with an empty database and is
# driven only by the messages the previous phase actually produced — so no phase
# can accidentally read state that would have been on another machine. What that
# tests and containers would not is whether the two halves agree about what
# every message means, which is the part that breaks.
RSpec.describe "a sample referred between two facilities", mode: :local, type: :request do
  # Shared by every node in reality, because it is replicated from the capital
  # before any of this happens. Kept across the phases for the same reason —
  # the register included, which is how one node can address a parcel to a
  # laboratory in another unit by code alone.
  before do
    create(:facility, national_code: "HCM", name: "Hospital Central de Maputo")
    create(:facility, national_code: "MAP", name: "Hospital Provincial de Maputo")
    create(:lab, national_code: "HCM-LAB", facility_code: "HCM", name: "Laboratório do HCM")
    create(:lab, national_code: "MAP-LAB-CENTRAL", facility_code: "MAP", name: "Laboratório Central de Maputo")
  end

  let!(:specimen_type) { create(:specimen_type, name: "Sangue total") }
  let!(:test_type) { create(:test_type, name: "Carga viral") }
  let!(:indicator) { create(:indicator, name: "Carga viral", unit: "cópias/mL") }

  it "comes back to the clinic that took it, under the same tracking number" do
    # Routes are drawn on the first request the process makes, and this example
    # spends its middle pretending to be a national node — which has no EMR
    # endpoints. Drawing them now means the ones this node really has are the
    # ones that end up in the route set.
    Rails.application.reload_routes_unless_loaded

    tracking_number = nil

    # ---- 1. HCM raises the sample and sends it away --------------------------
    from_hcm = as_node("HCM") do
      order = raise_order_at("HCM")
      tracking_number = order.tracking_number

      order.claim!(lab_code: "HCM-LAB", actor: "tec.mabjaia")
      order.transition_to!(Order::SPECIMEN_COLLECTED, actor: "enf.langa")
      order.transition_to!(Order::IN_PROGRESS, actor: "tec.mabjaia")

      Referral.dispatch!(order: order, to_lab_code: "MAP-LAB-CENTRAL",
                         courier: "Transporte MISAU", actor: "tec.mabjaia")

      expect(order.reload.status).to eq(Order::REFERRED_OUT)
      outbox_wire
    end

    # ---- 2. The capital routes it to MAP ------------------------------------
    for_map = rebuild_the_national_node(from_hcm => "HCM") { inbound_for("MAP") }

    expect(for_map.map { |event| event["type"] }).to include(OutboxEvent::REFERRAL_DISPATCHED)

    # ---- 3. MAP receives the sample, runs it, and reports ---------------------
    from_map = as_node("MAP") do
      clear_the_node
      Sync::Pull.new(transport: RecordedInbound.new(for_map), node_code: "MAP").call

      # It arrived as work, with everything the bench needs, and under the
      # number the clinic at HCM is still asking after.
      order = Order.find_by!(tracking_number: tracking_number)
      expect(order.status).to eq(Order::REFERRED_IN)
      expect(order.order_tests.sole.test_type).to eq(test_type)
      expect(order.referrals.sole.from_facility_code).to eq("HCM")

      # Against none of this unit's benches yet. The laboratory that sent it
      # away is on the referral, where it belongs; writing it on the order would
      # file the sample here under a laboratory that is not here.
      expect(order.receiving_lab_code).to be_nil
      expect(order.referrals.sole.from_lab_code).to eq("HCM-LAB")

      # But addressed to this unit, which is the whole of how a bench here ever
      # finds it: what a laboratory polls is scoped by the unit holding the
      # sample, and left as HCM the parcel arrives at MAP invisible to every
      # laboratory in it and untouchable by all of them — a referral that fails
      # while looking, from both ends, like it worked.
      expect(order.receiving_facility_code).to eq("MAP")

      # So the bench polls the way an mLab does, and the sample is in the answer
      # before anybody here has said anything about it.
      lis = create(:api_client, :sislab, facility_code: "MAP", lab_code: "MAP-LAB-CENTRAL")
      lis_token = issue_key(api_client: lis, scopes: %w[orders:read]).last

      get "/api/v3/lab/pending-orders",
          params: { since: 0, lab_code: "MAP-LAB-CENTRAL" }, headers: auth_headers(lis_token)

      expect(response).to have_http_status(:ok)
      waiting = response.parsed_body["data"].sole
      expect(waiting["tracking_number"]).to eq(tracking_number)
      expect(waiting["status"]).to eq(Order::REFERRED_IN)
      expect(waiting.dig("referral", "to_lab_code")).to eq("MAP-LAB-CENTRAL")

      Referral.find_by!(tracking_number: tracking_number)
              .receive!(actor: "tec.chissano", remarks: "chegou às 14h")

      # Opening the parcel is what makes it this bench's work, and the feed it
      # polls is scoped by exactly this column.
      expect(order.reload.receiving_lab_code).to eq("MAP-LAB-CENTRAL")
      expect(order.claimed_at).to be_present

      order.reload.transition_to!(Order::SPECIMEN_COLLECTED, actor: "tec.chissano")
      order.transition_to!(Order::IN_PROGRESS, actor: "tec.chissano")

      order_test = order.order_tests.sole
      order_test.transition_to!(OrderTest::IN_PROGRESS, actor: "tec.chissano")
      TestResult.record!(order_test: order_test, indicator: indicator, value: "< 20",
                         unit: "cópias/mL", recorded_by: "tec.chissano")
      order_test.transition_to!(OrderTest::COMPLETED, actor: "tec.chissano")
      order.transition_to!(Order::COMPLETED, actor: "dr.sitoe")

      outbox_wire
    end

    # ---- 4. The capital routes the result back to HCM ------------------------
    for_hcm = rebuild_the_national_node(from_hcm => "HCM", from_map => "MAP") do
      # The capital holds one sample, not two, however many nodes have touched it.
      expect(Order.where(tracking_number: tracking_number).count).to eq(1)
      expect(Order.sole.status).to eq(Order::COMPLETED)
      expect(Referral.sole).to be_received

      inbound_for("HCM")
    end

    expect(for_hcm.map { |event| event["type"] })
      .to include(OutboxEvent::REFERRAL_RECEIVED, OutboxEvent::TEST_RESULT_RECORDED)

    # ---- 5. HCM takes the result in, and its EMR reads it --------------------
    as_node("HCM") do
      clear_the_node
      replay(from_hcm, node_code: "HCM")
      Sync::Pull.new(transport: RecordedInbound.new(for_hcm), node_code: "HCM").call

      order = Order.find_by!(tracking_number: tracking_number)

      # Every stamp the journey collected, on the node that started it.
      referral = order.referrals.sole
      expect(referral.dispatched_at).to be_present
      expect(referral.received_at).to be_present
      expect(referral.transport_time).to be >= 0
      expect(referral.to_lab_code).to eq("MAP-LAB-CENTRAL")

      expect(order.test_results.current.sole.value).to eq("< 20")
      expect(order.test_results.current.sole.recorded_by).to eq("tec.chissano")

      # And the clinic's own system finds it by polling as it always does,
      # under the number it was given on the first day.
      emr = create(:api_client, kind: "emr", facility_code: "HCM")
      token = issue_key(api_client: emr, scopes: %w[results:read]).last

      get "/api/v3/results", params: { since: 0 }, headers: auth_headers(token)

      expect(response).to have_http_status(:ok)
      reading = response.parsed_body["data"].sole
      expect(reading["tracking_number"]).to eq(tracking_number)
      expect(reading["value"]).to eq("< 20")
      expect(reading["indicator"]).to include("national_code" => indicator.national_code)
    end
  end

  # The sample a clinic raises, through the same intake an EMR uses.
  def raise_order_at(facility_code)
    OrderRequest.new({
                       patient: { national_id: "110100234567A", name: "Ana Macuácua", sex: "F" },
                       order: { sending_facility_code: facility_code, receiving_lab_code: "#{facility_code}-LAB",
                                specimen_type: { national_code: specimen_type.national_code } },
                       tests: [ { test_type: { national_code: test_type.national_code } } ]
                     }, api_client: create(:api_client, kind: "emr", facility_code: facility_code)).create!
  end

  # What this node would push, in the order it would push it.
  def outbox_wire
    OutboxEvent.order(:id).map { |event| event.to_wire.deep_stringify_keys }
  end

  # What the capital is holding for a node, in the shape its inbound feed
  # returns — the same fields Api::V3::Sync::InboundController sends.
  def inbound_for(node_code)
    InboundDelivery.for_node(node_code).order(:revision).map do |delivery|
      event = delivery.inbound_event

      { "revision" => delivery.revision, "node_code" => event.node_code, "event_uuid" => event.event_uuid,
        "aggregate_uuid" => event.aggregate_uuid, "sequence" => event.sequence, "type" => event.type,
        "occurred_at" => event.occurred_at.iso8601, "payload" => event.payload }
    end
  end

  # The capital, built from nothing but the batches it has been sent. Rebuilding
  # it rather than carrying it between phases is deliberate: a national node
  # that cannot be reconstructed from the events it received would be holding
  # state nobody else can account for.
  def rebuild_the_national_node(batches)
    as_the_national_node do
      clear_the_node
      batches.each { |wire, node_code| Sync::Ingest.new(node_code: node_code, events: wire).call }
      yield
    end
  end

  def replay(wire, node_code:)
    Current.replicating = true
    Sync::Ingest.new(node_code: node_code, events: wire).call
  ensure
    Current.replicating = nil
  end

  # Everything about samples and synchronisation. The dictionary stays: it is
  # replicated from the capital long before any of this, and every node has it.
  def clear_the_node
    InboundDelivery.delete_all
    InboundEvent.delete_all
    OutboxEvent.delete_all
    SyncCursor.delete_all
    Referral.delete_all
    TestResult.delete_all
    StatusEvent.delete_all
    OrderTest.delete_all
    Order.delete_all
    Patient.delete_all
  end

  # A node is a health facility, and answers to its entry in the register. The
  # laboratories inside it are addressed by their own codes, but the node — the
  # thing that pushes, pulls and receives parcels — is the unit.
  def as_node(facility_code)
    facility = Facility.find_by!(national_code: facility_code)

    allow(SislabSync).to receive_messages(local?: true, national?: false, node_code: facility_code,
                                          facility_code: facility_code, facility: facility,
                                          labs: Lab.in_facility(facility_code))
    yield
  end

  def as_the_national_node
    allow(SislabSync).to receive_messages(local?: false, national?: true, node_code: "NATIONAL",
                                          facility_code: "NATIONAL", facility: nil, labs: Lab.none)
    yield
  end
end
