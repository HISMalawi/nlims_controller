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

  # The rule used to be that every term had to resolve to an active dictionary
  # entry or the whole request was refused. The national catalogue is still
  # being assembled, and that rule was refusing real work: a clinic could not
  # order an exam the laboratory runs every day because the catalogue had not
  # reached it. A term is now kept as it was written, with whatever code came
  # with it, so it can be linked once the catalogue does.
  describe "a term the dictionary does not carry" do
    it "takes the order and keeps the code it was given" do
      post_order(payload(tests: [ { test_type: { national_code: "MOZ-TT-9999", name: "Ferritina" } } ]))

      expect(response).to have_http_status(:created)

      test = Order.sole.order_tests.sole
      expect(test.test_type).to be_nil
      expect(test.test_code).to eq("MOZ-TT-9999")
      expect(test.test_name).to eq("Ferritina")
    end

    it "takes an exam named with nothing but its name" do
      post_order(payload(tests: [ { test_type: "Ferritina" } ]))

      expect(response).to have_http_status(:created)
      expect(Order.sole.order_tests.sole.test_type_label).to eq("Ferritina")
    end

    # A name is the handle a laboratory works from, so a name that matches one
    # active entry is the entry — no code needed on either side.
    it "links an exam named only by name when the name is unambiguous" do
      post_order(payload(tests: [ { test_type: "Hemograma" } ]))

      expect(Order.sole.order_tests.sole.test_type).to eq(test_type)
    end

    it "takes a specimen type the dictionary does not carry" do
      post_order(payload(order: { specimen_type: "Aspirado medular" }))

      expect(response).to have_http_status(:created)
      expect(Order.sole.specimen_type_label).to eq("Aspirado medular")
    end

    # A retired entry is still the closest thing this node knows to what was
    # asked for, and refusing it would send the clinic back to paper.
    it "links a test that has been retired rather than refusing it" do
      test_type.retire!(actor: "spec")

      post_order

      expect(response).to have_http_status(:created)
      expect(Order.sole.order_tests.sole.test_type).to eq(test_type)
    end

    # A panel this node does not know cannot be expanded into its members, so it
    # stands as one test under the name it was asked for, and the laboratory
    # adds what it actually ran at the bench.
    it "keeps an unknown panel as a single test" do
      post_order(payload(tests: [ { test_panel: "Bioquímica completa" } ]))

      expect(response).to have_http_status(:created)

      test = Order.sole.order_tests.sole
      expect(test.test_name).to eq("Bioquímica completa")
      expect(test.panel_name).to eq("Bioquímica completa")
    end

    # The one refusal left. A test with nothing on it is not a loose end
    # anybody can tie up later: nobody would know what was asked for.
    it "refuses a test that names nothing at all, by position" do
      expect do
        post_order(payload(tests: [
                             { test_type: { national_code: test_type.national_code } },
                             { method_of_testing: "PCR" }
                           ]))
      end.not_to change(Order, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("errors", 0, "field")).to eq("tests[1].test_type")
    end
  end

  # An mLab instance serves several laboratories of the same unit, each under its
  # own code, and says which one is speaking in the `lab` block. A laboratory the
  # node has never seen is registered from what that block says rather than
  # refused: it has already taken the sample, so it exists.
  describe "the laboratory sending the sample" do
    def post_from_lab(lab, order: {})
      post_order(payload(order: order).merge(lab: lab))
    end

    it "registers a laboratory it has never seen, and takes the sample" do
      post_from_lab({ code: "LAB07", name: "Laboratório de Bioquímica", phone: "840000111" })

      expect(response).to have_http_status(:created)

      lab = Lab.find_by!(facility_code: "HCM", source_code: "LAB07")
      expect(lab.name).to eq("Laboratório de Bioquímica")
      expect(lab.phone).to eq("840000111")
      expect(lab).to be_local
      expect(Order.sole.receiving_lab_code).to eq("LAB07")
    end

    # Only the capital issues national codes; this is how it hears of the
    # laboratory at all.
    it "announces the new laboratory to the capital" do
      post_from_lab({ code: "LAB07", name: "Laboratório de Bioquímica" })

      lab = Lab.find_by!(source_code: "LAB07")
      event = OutboxEvent.find_by(type: OutboxEvent::LAB_REGISTERED, aggregate_uuid: lab.uuid)

      expect(event.payload).to include("source_code" => "LAB07", "facility_code" => "HCM")
    end

    it "registers it once, however many samples arrive from it" do
      2.times { post_from_lab({ code: "LAB07", name: "Laboratório de Bioquímica" }) }

      expect(Lab.where(source_code: "LAB07").count).to eq(1)
      expect(OutboxEvent.where(type: OutboxEvent::LAB_REGISTERED).count).to eq(1)
    end

    it "uses the national code once the capital has named the laboratory" do
      create(:lab, national_code: "MOZ-LAB-0042", facility_code: "HCM", source_code: "LAB07")

      post_from_lab({ code: "LAB07", name: "Laboratório de Bioquímica" })

      expect(Order.sole.receiving_lab_code).to eq("MOZ-LAB-0042")
      expect(OutboxEvent.where(type: OutboxEvent::LAB_REGISTERED)).to be_empty
    end

    # A code on its own is not enough to register anything — there would be no
    # name to put on it — so it is kept as written, the way an unknown
    # dictionary term is.
    it "keeps a bare code it cannot place, rather than inventing a laboratory" do
      post_order(payload(order: { receiving_lab_code: "LAB99" }))

      expect(response).to have_http_status(:created)
      expect(Order.sole.receiving_lab_code).to eq("LAB99")
      expect(Lab.where(source_code: "LAB99")).to be_empty
    end
  end

  describe "the codes the node fills in for itself" do
    # A clinician asks the unit for a test; which bench runs it is settled at the
    # bench, when one of them claims the sample. It used to default to the
    # node's own laboratory, from when a node was one.
    it "leaves the order at the unit when no laboratory is named" do
      post_order(payload.tap { |body| body[:order].delete(:receiving_lab_code) })

      expect(response).to have_http_status(:created)
      expect(Order.sole.receiving_facility_code).to eq(api_client.facility_code)
      expect(Order.sole.receiving_lab_code).to be_nil
    end

    it "uses the facility on the key, whatever the payload claims" do
      post_order(payload(order: { sending_facility_code: "XAI" }))

      expect(response).to have_http_status(:created)
      expect(Order.sole.sending_facility_code).to eq("HCM")
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

      post_order(payload(tests: [ { method_of_testing: "PCR" } ]), key: key)
      expect(response).to have_http_status(:unprocessable_content)

      post_order(payload, key: key)
      expect(response).to have_http_status(:created)
    end
  end
end
