# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GET /api/v3/sync/inbound", mode: :national, type: :request do
  let(:api_client) { create(:api_client, kind: "node", facility_code: "MAP") }
  let(:token) { issue_key(api_client: api_client, scopes: %w[sync:pull sync:push]).last }

  let(:order_uuid) { SecureRandom.uuid }
  let(:referral_uuid) { SecureRandom.uuid }

  def specimen_type = @specimen_type ||= create(:specimen_type, name: "Sangue total")
  def test_type = @test_type ||= create(:test_type, name: "Hemograma")

  # What node HCM would have sent when its laboratory referred a sample to MAP.
  def dispatch_event(sequence: 1)
    {
      event_uuid: SecureRandom.uuid, aggregate_uuid: order_uuid, sequence: sequence,
      type: OutboxEvent::REFERRAL_DISPATCHED, occurred_at: Time.current.iso8601,
      payload: {
        referral: { uuid: referral_uuid, tracking_number: "MZ-HCM-26229-0001", state: "dispatched",
                    from_facility_code: "HCM", from_lab_code: "HCM-LAB",
                    to_facility_code: "MAP", to_lab_code: "MAP-LAB-CENTRAL",
                    dispatched_at: Time.current.iso8601, courier: "Transporte MISAU" },
        order: {
          uuid: order_uuid, tracking_number: "MZ-HCM-26229-0001", status: "referred_out",
          priority: "routine", sending_facility_code: "HCM", receiving_lab_code: "HCM-LAB",
          specimen_type: { national_code: specimen_type.national_code },
          patient: { uuid: SecureRandom.uuid, national_id: "110100234567A", name: "Ana Macuácua", sex: "F" },
          tests: [ { uuid: SecureRandom.uuid, status: "in_progress",
                     test_type: { national_code: test_type.national_code } } ]
        }
      }
    }
  end

  def push_from(node_code, events)
    post "/api/v3/sync/events",
         params: { node_code: node_code, events: events }.to_json,
         headers: { "Authorization" => "Bearer #{issue_key(api_client: create(:api_client, :node),
                                                           scopes: %w[sync:push]).last}",
                    "Content-Type" => "application/json" }
  end

  def get_inbound(node_code: "MAP", bearer: token, **query)
    get "/api/v3/sync/inbound", params: { node_code: node_code, **query }, headers: auth_headers(bearer)
  end

  describe "routing a referred sample" do
    before { push_from("HCM", [ dispatch_event ]) }

    it "holds the dispatch for the laboratory it was sent to" do
      get_inbound(since: 0)

      expect(response).to have_http_status(:ok)

      event = response.parsed_body["data"].sole
      expect(event["type"]).to eq(OutboxEvent::REFERRAL_DISPATCHED)
      expect(event["node_code"]).to eq("HCM")
      expect(event.dig("payload", "order", "tracking_number")).to eq("MZ-HCM-26229-0001")
    end

    # Without this, the two nodes holding one sample would push each other's
    # news round in a circle for ever.
    it "does not hand a node back its own news" do
      get_inbound(node_code: "HCM", bearer: issue_key(api_client: create(:api_client, kind: "node",
                                                                                     facility_code: "HCM"),
                                                      scopes: %w[sync:pull]).last, since: 0)

      expect(response.parsed_body["data"]).to be_empty
    end

    it "hands over nothing twice" do
      get_inbound(since: 0)
      cursor = response.parsed_body.dig("meta", "next_cursor")

      get_inbound(since: cursor)

      expect(response.parsed_body["data"]).to be_empty
    end

    # Once the sample has been referred, the origin has to hear what the
    # receiving laboratory does with it.
    it "routes what the receiving laboratory reports back to the origin" do
      push_from("MAP", [ {
                  event_uuid: SecureRandom.uuid, aggregate_uuid: order_uuid, sequence: 1,
                  type: OutboxEvent::REFERRAL_RECEIVED, occurred_at: Time.current.iso8601,
                  payload: { referral: { uuid: referral_uuid, state: "received",
                                         received_at: Time.current.iso8601 } }
                } ])

      hcm = create(:api_client, kind: "node", facility_code: "HCM")
      get_inbound(node_code: "HCM", bearer: issue_key(api_client: hcm, scopes: %w[sync:pull]).last, since: 0)

      types = response.parsed_body["data"].map { |event| event["type"] }
      expect(types).to eq([ OutboxEvent::REFERRAL_RECEIVED ])
    end

    it "says when there is more behind the page it gave" do
      push_from("HCM", [ dispatch_event(sequence: 2).merge(type: OutboxEvent::ORDER_STATUS_CHANGED,
                                                           payload: { to_status: "referred_out" }) ])

      get_inbound(since: 0, limit: 1)

      expect(response.parsed_body["data"].length).to eq(1)
      expect(response.parsed_body.dig("meta", "has_more")).to be(true)
    end
  end

  describe "what it refuses" do
    it "answers 403 for a node asking for another node's inbound" do
      get_inbound(node_code: "XAI")

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("facility_mismatch")
    end

    it "answers 403 for a key that may push but not pull" do
      pusher = issue_key(api_client: api_client, scopes: %w[sync:push]).last

      get_inbound(bearer: pusher)

      expect(response).to have_http_status(:forbidden)
    end

    it "answers 401 without a key" do
      get "/api/v3/sync/inbound"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
