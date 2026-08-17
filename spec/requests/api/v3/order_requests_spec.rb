# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /api/v3/order-requests", mode: :local, type: :request do
  let(:api_client) { create(:api_client, facility_code: "HCM") }
  let(:credentials) { issue_key(api_client: api_client, scopes: %w[orders:write]) }
  let(:token) { credentials.last }

  let(:specimen_type) { create(:specimen_type, name: "Sangue total") }
  let(:test_type) { create(:test_type, name: "Hemograma") }

  def payload(overrides = {})
    {
      patient: { national_id: "110100234567A", name: "Ana Macuácua", sex: "F", birthdate: "1991-04-12" },
      order: {
        receiving_lab_code: "HCM-LAB",
        lab_code: "HCM-LAB-BIOQ",
        priority: "routine",
        requested_by: "Dr. J. Sitoe",
        clinical_history: "Febre há 5 dias",
        specimen_type: { national_code: specimen_type.national_code },
        collected_at: "2026-09-14T08:20:00+02:00"
      },
      tests: [ { test_type: { national_code: test_type.national_code } } ]
    }.deep_merge(overrides)
  end

  def post_order(body = payload, key: SecureRandom.uuid, bearer: token)
    post "/api/v3/order-requests",
         params: body.to_json,
         headers: { "Authorization" => "Bearer #{bearer}",
                    "Idempotency-Key" => key,
                    "Content-Type" => "application/json" }
  end

  describe "creating an order" do
    it "answers 201 with the tracking number it generated" do
      post_order

      expect(response).to have_http_status(:created)

      data = response.parsed_body["data"]
      expect(data["tracking_number"]).to match(TrackingNumber::FORMAT)
      expect(data["status"]).to eq(Order::REQUESTED)
      expect(data["order_uuid"]).to be_present
    end

    it "records the patient, the order and its tests" do
      post_order

      order = Order.find_by!(uuid: response.parsed_body.dig("data", "order_uuid"))
      expect(order.patient.national_id).to eq("110100234567A")
      expect(order.specimen_type).to eq(specimen_type)
      expect(order.order_tests.map(&:test_type)).to eq([ test_type ])
      expect(order.receiving_lab_code).to eq("HCM-LAB")
      expect(order.clinical_history).to eq("Febre há 5 dias")
    end

    # The key already knows which facility it speaks for. Making the EMR repeat
    # it only creates a field it can get wrong.
    it "takes the facility from the key when the payload leaves it out" do
      post_order

      expect(Order.sole.sending_facility_code).to eq("HCM")
    end

    it "remembers which system and which key raised it" do
      post_order

      order = Order.sole
      expect(order.source_system).to eq("emr")
      expect(order.source_client).to eq(api_client)
    end

    it "starts the history with the client that asked" do
      post_order

      expect(Order.sole.own_status_events.sole.actor).to eq(api_client.name)
    end

    # The same person arriving twice is one patient, whichever order came first.
    it "reuses the patient the national identifier already names" do
      patient = create(:patient, national_id: "110100234567A", name: "Ana M.")

      expect { post_order }.not_to change(Patient, :count)
      expect(patient.reload.name).to eq("Ana Macuácua")
    end

    it "creates a patient per order when nobody has an identifier" do
      post_order(payload(patient: { national_id: nil }))
      post_order(payload(patient: { national_id: nil }))

      expect(Patient.count).to eq(2)
    end

    it "expands a panel into the tests inside it, remembering the panel" do
      panel = create(:test_panel, name: "Perfil renal")
      panel.test_types << create_list(:test_type, 2)

      post_order(payload(tests: [ { test_panel: { national_code: panel.national_code } } ]))

      expect(response).to have_http_status(:created)
      expect(Order.sole.order_tests.count).to eq(2)
      expect(Order.sole.order_tests.map(&:test_panel).uniq).to eq([ panel ])
    end
  end

  describe "a dictionary the EMR has not caught up with" do
    it "names the code it does not know" do
      post_order(payload(tests: [ { test_type: { national_code: "MOZ-TT-9999" } } ]))

      expect(response).to have_http_status(:unprocessable_content)

      error = response.parsed_body.dig("errors", 0)
      expect(error["code"]).to eq("unprocessable")
      expect(error["message"]).to include("MOZ-TT-9999")
      expect(error["field"]).to eq("tests[0].test_type")
    end

    it "names the position of the bad code among several tests" do
      post_order(payload(tests: [
                           { test_type: { national_code: test_type.national_code } },
                           { test_type: { national_code: "MOZ-TT-9999" } }
                         ]))

      expect(response.parsed_body.dig("errors", 0, "field")).to eq("tests[1].test_type")
    end

    it "refuses a test that has been retired, rather than accepting it silently" do
      test_type.retire!(actor: "spec")

      post_order

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("errors", 0, "message")).to include("retired")
    end

    it "refuses an unknown specimen type by name" do
      post_order(payload(order: { specimen_type: { national_code: "MOZ-SP-9999" } }))

      expect(response.parsed_body.dig("errors", 0, "field")).to eq("order.specimen_type")
    end

    # Nothing is written when any part of the request is refused: an order
    # missing one of its tests is worse than no order at all.
    it "writes nothing at all when one code is bad" do
      expect do
        post_order(payload(tests: [
                             { test_type: { national_code: test_type.national_code } },
                             { test_type: { national_code: "MOZ-TT-9999" } }
                           ]))
      end.not_to change(Order, :count)
    end
  end

  describe "what it refuses" do
    it "answers 401 without a key" do
      post "/api/v3/order-requests",
           params: payload.to_json,
           headers: { "Idempotency-Key" => SecureRandom.uuid, "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("unauthenticated")
    end

    it "answers 403 for a key that may read orders but not raise them" do
      readers = issue_key(api_client: api_client, scopes: %w[orders:read])

      post_order(payload, bearer: readers.last)

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("insufficient_scope")
    end

    it "answers 403 for an order raised in another facility's name" do
      post_order(payload(order: { sending_facility_code: "XAI" }))

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("facility_mismatch")
      expect(Order.count).to be_zero
    end

    it "answers 422 for a request with no tests on it" do
      post_order(payload.merge(tests: []))

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("errors", 0, "field")).to eq("tests")
    end

    it "answers 422 for a patient with no name" do
      post_order(payload(patient: { name: nil }))

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "answers 400 without an Idempotency-Key" do
      post "/api/v3/order-requests",
           params: payload.to_json,
           headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("idempotency_key_required")
    end
  end

  # The acceptance criterion for this step: the network drops after the order
  # was written but before the answer arrived, and the EMR sends it again.
  describe "a retry after the network dropped" do
    it "returns the same tracking number without creating a second order" do
      key = SecureRandom.uuid

      post_order(payload, key: key)
      first = response.parsed_body

      expect { post_order(payload, key: key) }.not_to change(Order, :count)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to eq(first)
      expect(response.headers["Idempotent-Replay"]).to eq("true")
    end

    it "refuses the same key used for a different order" do
      key = SecureRandom.uuid

      post_order(payload, key: key)
      post_order(payload(order: { requested_by: "Dr. Outro" }), key: key)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("idempotency_key_reused")
    end

    it "does not consume the key when the request was refused" do
      key = SecureRandom.uuid

      post_order(payload(tests: [ { test_type: { national_code: "MOZ-TT-9999" } } ]), key: key)
      expect(response).to have_http_status(:unprocessable_content)

      post_order(payload, key: key)
      expect(response).to have_http_status(:created)
    end
  end
end
