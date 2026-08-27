# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /api/v3/sync/events", mode: :national, type: :request do
  let(:api_client) { create(:api_client, :node) }
  let(:token) { issue_key(api_client: api_client, scopes: %w[sync:push]).last }

  # The events a local node would have produced. Built here rather than by
  # running the local side, so the national node is tested against the contract
  # and not against whatever the other half happens to do today.
  let(:order_uuid) { SecureRandom.uuid }

  def patient_uuid = @patient_uuid ||= SecureRandom.uuid
  def specimen_type = @specimen_type ||= create(:specimen_type, name: "Sangue total")
  def test_type = @test_type ||= create(:test_type, name: "Hemograma")
  def indicator = @indicator ||= create(:indicator, name: "Hemoglobina")

  def order_created(sequence: 1, **overrides)
    event(sequence: sequence, type: "order.created", payload: {
            tracking_number: "MZ-HCM-26229-0001", to_status: "requested", actor: "emr-hcm",
            order: {
              uuid: order_uuid, tracking_number: "MZ-HCM-26229-0001", status: "requested",
              priority: "routine", sending_facility_code: "HCM", receiving_lab_code: "HCM-LAB",
              specimen_type: { national_code: specimen_type.national_code },
              patient: { uuid: patient_uuid, national_id: "110100234567A", name: "Ana Macuácua",
                         sex: "F", birthdate: "1991-04-12" }
            }.merge(overrides)
          })
  end

  def event(sequence:, type:, payload:, aggregate_uuid: order_uuid, event_uuid: SecureRandom.uuid)
    {
      event_uuid: event_uuid, aggregate_uuid: aggregate_uuid, sequence: sequence,
      type: type, occurred_at: Time.current.iso8601, payload: payload
    }
  end

  def post_events(events, node_code: "HCM", bearer: token)
    post "/api/v3/sync/events",
         params: { node_code: node_code, events: events }.to_json,
         headers: { "Authorization" => "Bearer #{bearer}", "Content-Type" => "application/json" }
  end

  def accepted = response.parsed_body.dig("data", "accepted")
  def rejected = response.parsed_body.dig("data", "rejected")

  describe "receiving a sample" do
    it "creates the order and the patient it carries" do
      post_events([ order_created ])

      expect(response).to have_http_status(:ok)
      expect(accepted.length).to eq(1)
      expect(rejected).to be_empty

      order = Order.find_by!(uuid: order_uuid)
      expect(order.tracking_number).to eq("MZ-HCM-26229-0001")
      expect(order.patient.national_id).to eq("110100234567A")
      expect(order.specimen_type).to eq(specimen_type)
    end

    # The order carries its patient, so a sample can be applied for someone this
    # node has never heard of. Waiting for patient.upserted would mean ordering
    # two aggregates against each other, which the sequence deliberately does
    # not do.
    it "does not wait for a patient event that may never come" do
      expect { post_events([ order_created ]) }.to change(Patient, :count).by(1)
    end

    it "keeps the tracking number the sample was given" do
      post_events([ order_created ])

      expect(Order.sole.tracking_number).to eq("MZ-HCM-26229-0001")
    end

    it "writes the transition into the history, naming the node it came from" do
      post_events([ order_created,
                    event(sequence: 2, type: "order.status_changed",
                          payload: { to_status: "accepted", from_status: "requested" }) ])

      order = Order.find_by!(uuid: order_uuid)
      expect(order.status).to eq(Order::ACCEPTED)
      expect(order.own_status_events.last.actor).to eq("node:HCM")
    end

    it "applies a test and the readings recorded against it" do
      test_uuid = SecureRandom.uuid
      result_uuid = SecureRandom.uuid

      post_events([
                    order_created,
                    event(sequence: 2, type: "order.test_added", payload: {
                            test: { uuid: test_uuid, status: "pending",
                                    test_type: { national_code: test_type.national_code } }
                          }),
                    event(sequence: 3, type: "test.result_recorded", payload: {
                            uuid: result_uuid, order_test_uuid: test_uuid,
                            indicator: { national_code: indicator.national_code },
                            value: "12.4", unit: "g/dL", recorded_at: Time.current.iso8601,
                            recorded_by: "tec.mabjaia", replaces: []
                          })
                  ])

      expect(rejected).to be_empty

      result = TestResult.find_by!(uuid: result_uuid)
      expect(result.value).to eq("12.4")
      expect(result.order_test.test_type).to eq(test_type)
      expect(result.order_test.order.uuid).to eq(order_uuid)
    end

    it "marks the reading a correction replaces" do
      test_uuid = SecureRandom.uuid
      wrong_uuid = SecureRandom.uuid

      post_events([
                    order_created,
                    event(sequence: 2, type: "order.test_added",
                          payload: { test: { uuid: test_uuid, status: "in_progress",
                                             test_type: { national_code: test_type.national_code } } }),
                    event(sequence: 3, type: "test.result_recorded",
                          payload: { uuid: wrong_uuid, order_test_uuid: test_uuid,
                                     indicator: { national_code: indicator.national_code },
                                     value: "12.4", recorded_at: Time.current.iso8601, replaces: [] }),
                    event(sequence: 4, type: "test.result_recorded",
                          payload: { uuid: SecureRandom.uuid, order_test_uuid: test_uuid,
                                     indicator: { national_code: indicator.national_code },
                                     value: "14.2", recorded_at: Time.current.iso8601,
                                     replaces: [ wrong_uuid ] })
                  ])

      expect(TestResult.find_by!(uuid: wrong_uuid)).to be_replaced
      expect(TestResult.current.sole.value).to eq("14.2")
    end

    it "applies a rejection with the reason the laboratory gave" do
      reason = create(:rejection_reason, name: "Amostra hemolisada")

      post_events([ order_created,
                    event(sequence: 2, type: "order.status_changed", payload: { to_status: "accepted" }),
                    event(sequence: 3, type: "specimen.rejected",
                          payload: { to_status: "rejected", reason: "Amostra hemolisada",
                                     rejection_reason: { national_code: reason.national_code } }) ])

      order = Order.find_by!(uuid: order_uuid)
      expect(order.status).to eq(Order::REJECTED)
      expect(order.rejection_reason).to eq(reason)
    end

    # The machine is enforced where the change is made. A replica that refused a
    # state the node of record had already committed would disagree with it for
    # ever, and would do so silently.
    it "applies a status the local machine would not allow from here" do
      post_events([ order_created,
                    event(sequence: 2, type: "order.status_changed", payload: { to_status: "completed" }) ])

      expect(rejected).to be_empty
      expect(Order.find_by!(uuid: order_uuid).status).to eq(Order::COMPLETED)
    end
  end

  describe "sending the same batch twice" do
    it "accepts it again and changes nothing" do
      events = [ order_created ]

      post_events(events)
      first = accepted

      expect { post_events(events) }.not_to change(Order, :count)

      expect(response).to have_http_status(:ok)
      expect(accepted).to eq(first)
      expect(InboundEvent.count).to eq(1)
    end

    it "recognises one event it has already applied inside a new batch" do
      first = order_created
      post_events([ first ])

      post_events([ first, event(sequence: 2, type: "order.status_changed", payload: { to_status: "accepted" }) ])

      expect(accepted.length).to eq(2)
      expect(Order.find_by!(uuid: order_uuid).status).to eq(Order::ACCEPTED)
    end
  end

  describe "events that arrive out of order" do
    # Applying a status change to a sample this node has not been told about
    # would be a guess. It waits instead, and applies the moment the gap fills.
    it "waits for the event before it, rather than applying the wrong thing" do
      post_events([ event(sequence: 2, type: "order.status_changed", payload: { to_status: "accepted" }) ])

      expect(rejected).to be_empty
      expect(Order.count).to be_zero
      expect(InboundEvent.pending.count).to eq(1)
    end

    it "applies the whole stream once the missing event arrives" do
      post_events([ event(sequence: 2, type: "order.status_changed", payload: { to_status: "accepted" }),
                    event(sequence: 3, type: "order.status_changed", payload: { to_status: "specimen_collected" }) ])

      post_events([ order_created ])

      expect(Order.find_by!(uuid: order_uuid).status).to eq(Order::SPECIMEN_COLLECTED)
      expect(InboundEvent.pending).to be_empty
      expect(InboundEvent.applied.count).to eq(3)
    end

    it "sorts a batch that arrives shuffled" do
      post_events([ event(sequence: 2, type: "order.status_changed", payload: { to_status: "accepted" }),
                    order_created ])

      expect(Order.find_by!(uuid: order_uuid).status).to eq(Order::ACCEPTED)
    end

    # One sample stuck must never hold up another facility's work.
    it "does not let one blocked sample delay a different one" do
      other_uuid = SecureRandom.uuid

      post_events([
                    event(sequence: 2, aggregate_uuid: other_uuid, type: "order.status_changed",
                          payload: { to_status: "accepted" }),
                    order_created
                  ])

      expect(Order.find_by!(uuid: order_uuid)).to be_present
      expect(InboundEvent.pending.sole.aggregate_uuid).to eq(other_uuid)
    end
  end

  describe "events it cannot apply" do
    # This used to be a rejection — unknown_dictionary_item — which blocked the
    # sending node's whole stream until somebody in the capital noticed. Local
    # nodes order exams the national catalogue has not reached, so a reading
    # refused here is a reading lost. The term travels with its name, and the
    # capital stores what was measured either way.
    it "takes a test whose code the national dictionary does not have" do
      post_events([ order_created,
                    event(sequence: 2, type: "order.test_added",
                          payload: { test: { uuid: SecureRandom.uuid, status: "pending",
                                             test_type: { national_code: "MOZ-TT-9999",
                                                          name: "Ferritina" } } }) ])

      expect(rejected).to be_empty

      added = Order.find_by!(uuid: order_uuid).order_tests.find_by(test_code: "MOZ-TT-9999")
      expect(added.test_type).to be_nil
      expect(added.test_name).to eq("Ferritina")
    end

    it "does not block the rest of that sample's stream over a term it does not carry" do
      post_events([ order_created,
                    event(sequence: 2, type: "order.test_added",
                          payload: { test: { uuid: SecureRandom.uuid, status: "pending",
                                             test_type: { national_code: "MOZ-TT-9999",
                                                          name: "Ferritina" } } }),
                    event(sequence: 3, type: "order.status_changed", payload: { to_status: "accepted" }) ])

      expect(Order.find_by!(uuid: order_uuid).status).to eq(Order::ACCEPTED)
      expect(InboundEvent.rejected).to be_empty
    end

    it "rejects an event type it has never heard of" do
      post_events([ order_created, event(sequence: 2, type: "order.exploded", payload: {}) ])

      expect(rejected.first["code"]).to eq("unknown_type")
    end

    it "rejects an event with fields missing, naming them" do
      post_events([ { event_uuid: SecureRandom.uuid, type: "order.created", payload: {} } ])

      expect(rejected.first["code"]).to eq("malformed")
      expect(rejected.first["message"]).to include("aggregate_uuid")
    end
  end

  describe "what it refuses" do
    it "answers 401 without a key" do
      post "/api/v3/sync/events",
           params: { node_code: "HCM", events: [] }.to_json,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "answers 403 for a key without the push scope" do
      reader = issue_key(api_client: api_client, scopes: %w[dictionary:read])

      post_events([], bearer: reader.last)

      expect(response).to have_http_status(:forbidden)
    end

    it "answers 403 for a node sending another node's events" do
      pinned = create(:api_client, kind: "node", lab_code: "XAI-LAB")
      key = issue_key(api_client: pinned, scopes: %w[sync:push]).last

      post_events([ order_created ], node_code: "HCM", bearer: key)

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("lab_mismatch")
    end

    it "asks for the node code when the batch does not say" do
      post "/api/v3/sync/events",
           params: { events: [] }.to_json,
           headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("errors", 0, "field")).to eq("node_code")
    end
  end
end
