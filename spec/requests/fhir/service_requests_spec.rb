# frozen_string_literal: true

require "rails_helper"

RSpec.describe "FHIR ServiceRequest", mode: :local, type: :request do
  let(:token) { issue_key(api_client: api_client, scopes: %w[orders:read orders:write]).last }
  let(:specimen_type) { create(:specimen_type, name: "Sangue total") }
  let(:test_type) { create(:test_type, name: "Hemoglobina", loinc_code: "718-7") }

  def api_client
    @api_client ||= create(:api_client, facility_code: "HCM")
  end

  def headers(extra = {})
    { "Authorization" => "Bearer #{token}", "Content-Type" => "application/fhir+json" }.merge(extra)
  end

  def service_request(overrides = {})
    {
      resourceType: "ServiceRequest",
      identifier: [ { system: "http://emr.local/orders", value: "EMR-#{SecureRandom.hex(4)}" } ],
      status: "active",
      intent: "order",
      priority: "urgent",
      code: { coding: [ { system: Fhir.code_system("test_types"), code: test_type.national_code } ] },
      subject: { reference: "#doente" },
      specimen: [ { reference: "#amostra" } ],
      requester: { display: "Dr. J. Sitoe" },
      performer: [ { identifier: { system: Fhir.url("sid/lab-code"), value: "HCM-LAB" } } ],
      note: [ { text: "Febre há 5 dias" } ],
      contained: [
        {
          resourceType: "Patient",
          id: "doente",
          identifier: [ { system: Fhir.national_id_system, value: "110100234567A" } ],
          name: [ { text: "Ana Macuácua" } ],
          gender: "female",
          birthDate: "1991-04-12"
        },
        {
          resourceType: "Specimen",
          id: "amostra",
          type: { coding: [ { system: Fhir.code_system("specimen_types"), code: specimen_type.national_code } ] },
          collection: { collectedDateTime: "2026-09-14T08:20:00+02:00" }
        }
      ]
    }.deep_merge(overrides)
  end

  def post_request(body = service_request, extra_headers = {})
    post "/fhir/r4/ServiceRequest", params: body.to_json, headers: headers(extra_headers)
  end

  describe "creating an order" do
    it "answers 201 with the ServiceRequest it created" do
      post_request

      expect(response).to have_http_status(:created)
      expect(response.media_type).to eq("application/fhir+json")

      body = response.parsed_body
      expect(body["resourceType"]).to eq("ServiceRequest")
      expect(body["id"]).to eq(OrderTest.sole.uuid)
      expect(response.headers["Location"]).to end_with("/fhir/r4/ServiceRequest/#{OrderTest.sole.uuid}")
    end

    it "records the order through the same intake the JSON API uses" do
      post_request

      order = Order.sole
      expect(order.patient.national_id).to eq("110100234567A")
      expect(order.patient.sex).to eq("F")
      expect(order.specimen_type).to eq(specimen_type)
      expect(order.receiving_lab_code).to eq("HCM-LAB")
      expect(order.priority).to eq("urgent")
      expect(order.requested_by).to eq("Dr. J. Sitoe")
      expect(order.clinical_history).to eq("Febre há 5 dias")
      expect(order.order_tests.sole.test_type).to eq(test_type)
    end

    # The facility is the key's, never the payload's, exactly as in the JSON
    # intake: a client should not be able to raise an order for somewhere else.
    it "takes the facility from the key" do
      post_request

      expect(Order.sole.sending_facility_code).to eq("HCM")
    end

    it "puts the tracking number where an EMR will look for it" do
      post_request

      tracking = Order.sole.tracking_number
      body = response.parsed_body

      expect(body.dig("requisition", "value")).to eq(tracking)
      expect(body["identifier"].map { |identifier| identifier["value"] }).to include(tracking)
    end

    # A client that has never heard of the Idempotency-Key header still has to
    # be able to retry safely, and the placer order number is what makes a retry
    # recognisable as one.
    it "uses the placer order number as the idempotency key" do
      body = service_request
      post_request(body)
      created = response.parsed_body["id"]

      post_request(body)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["id"]).to eq(created)
      expect(response.headers["Idempotent-Replay"]).to eq("true")
      expect(Order.count).to eq(1)
    end

    it "refuses a request with nothing to make it repeatable" do
      post_request(service_request.except(:identifier))

      expect(response).to have_http_status(:bad_request)
      issue = response.parsed_body.dig("issue", 0)
      expect(issue["code"]).to eq("required")
      expect(issue.dig("details", "coding", 0, "code")).to eq("idempotency_key_required")
    end
  end

  describe "the codes it accepts" do
    it "accepts a LOINC code that has been curated into the dictionary" do
      post_request(service_request(code: { coding: [ { system: Fhir::LOINC_SYSTEM, code: "718-7" } ] }))

      expect(response).to have_http_status(:created)
      expect(OrderTest.sole.test_type).to eq(test_type)
    end

    # The catalogue arrived with no LOINC codes, so most of it is reachable only
    # by national code. An uncurated LOINC code identifies nothing on this node,
    # but it is still what the request was written with, so it is kept — with
    # the display text, which is what the laboratory actually reads.
    it "keeps a LOINC code nobody has curated, under the name it came with" do
      post_request(service_request(code: { coding: [ { system: Fhir::LOINC_SYSTEM, code: "2160-0",
                                                       display: "Creatinina" } ] }))

      expect(response).to have_http_status(:created)

      test = OrderTest.sole
      expect(test.test_type).to be_nil
      expect(test.test_code).to eq("2160-0")
      expect(test.test_name).to eq("Creatinina")
    end

    # The one refusal left: a concept with neither a code nor a word in it.
    it "refuses a code that says nothing, naming the field" do
      post_request(service_request(code: { coding: [] }))

      expect(response).to have_http_status(:unprocessable_content)
      issue = response.parsed_body.dig("issue", 0)
      expect(issue["code"]).to eq("invalid")
      expect(issue["expression"]).to eq([ "ServiceRequest.code" ])
    end

    it "understands a national code sent without a system" do
      post_request(service_request(code: { coding: [ { code: test_type.national_code } ] }))

      expect(response).to have_http_status(:created)
      expect(OrderTest.sole.test_type).to eq(test_type)
    end

    # An explicit national code and a LOINC code that happens to belong to a
    # panel must not resolve to the panel: what the client said outright wins.
    it "prefers the code the client named outright over one it can infer" do
      create(:test_panel, name: "Hemograma", loinc_code: "718-7").test_types << create(:test_type)

      post_request(service_request(code: { coding: [
        { system: Fhir::LOINC_SYSTEM, code: "718-7" },
        { system: Fhir.code_system("test_types"), code: test_type.national_code }
      ] }))

      expect(response).to have_http_status(:created)
      expect(OrderTest.sole.test_type).to eq(test_type)
    end
  end

  describe "a panel" do
    let(:panel) { create(:test_panel, name: "Hemograma completo") }
    let(:members) { create_list(:test_type, 3) }

    before { panel.test_types = members }

    # The laboratory runs the members one at a time, and each can be rejected or
    # referred on its own, so the client has to learn the identifiers of what it
    # actually got rather than the one it asked for.
    it "expands into a collection Bundle of the tests it produced" do
      post_request(service_request(code: {
        coding: [ { system: Fhir.code_system("test_panels"), code: panel.national_code } ]
      }))

      expect(response).to have_http_status(:created)

      body = response.parsed_body
      expect(body["resourceType"]).to eq("Bundle")
      expect(body["type"]).to eq("collection")
      expect(body["entry"].length).to eq(3)
      expect(Order.sole.order_tests.map(&:test_panel).uniq).to eq([ panel ])
    end
  end

  describe "a transaction Bundle" do
    let(:second_test) { create(:test_type, name: "Glicose") }

    def bundle
      {
        resourceType: "Bundle",
        type: "transaction",
        entry: [
          { resource: service_request[:contained][0].merge(id: nil).compact },
          { resource: service_request[:contained][1].merge(id: nil).compact },
          { resource: single_request(test_type) },
          { resource: single_request(second_test) }
        ]
      }
    end

    def single_request(type)
      service_request.except(:contained).deep_merge(
        code: { coding: [ { system: Fhir.code_system("test_types"), code: type.national_code } ] },
        subject: { reference: "Patient/desconhecido" },
        specimen: [ { reference: "Specimen/desconhecido" } ],
        requisition: { system: Fhir.tracking_number_system, value: "EMR-GRUPO-1" }
      )
    end

    it "creates one order carrying every test in the group" do
      post "/fhir/r4", params: bundle.to_json, headers: headers

      expect(response).to have_http_status(:created)

      body = response.parsed_body
      expect(body["type"]).to eq("transaction-response")
      expect(body["entry"].length).to eq(2)
      expect(body["entry"].map { |entry| entry.dig("response", "status") }).to all(eq("201 Created"))

      order = Order.sole
      expect(order.order_tests.map(&:test_type)).to contain_exactly(test_type, second_test)
      expect(order.specimen_type).to eq(specimen_type)
      expect(order.patient.name).to eq("Ana Macuácua")
    end

    # A code this node's catalogue does not carry is kept as it arrived rather
    # than refused — the national catalogue is still being assembled, and the
    # laboratory runs the exam either way.
    it "takes a test naming a code this node does not know" do
      unknown = bundle
      unknown[:entry][3][:resource][:code] = { coding: [ { code: "MOZ-TT-9999", display: "Ferritina" } ] }

      post "/fhir/r4", params: unknown.to_json, headers: headers

      expect(response).to have_http_status(:created)
      expect(Order.sole.order_tests.map(&:test_type_label)).to include("Ferritina")
    end

    # All or nothing, like the JSON intake: an order missing the test that could
    # not be read is worse than no order at all.
    it "writes nothing when one test names nothing at all" do
      broken = bundle
      broken[:entry][3][:resource][:code] = { coding: [] }

      post "/fhir/r4", params: broken.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(Order.count).to eq(0)
      expect(Patient.count).to eq(0)
    end

    it "refuses a batch Bundle rather than treating it as a transaction" do
      post "/fhir/r4", params: bundle.merge(type: "batch").to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("issue", 0, "expression")).to eq([ "Bundle.type" ])
    end
  end

  describe "refusals" do
    # `performer` used to be required, from when a node was a single laboratory
    # and there was exactly one right answer. A ServiceRequest comes from a
    # clinician asking the health facility for a test; the sample arrives at the
    # unit unclaimed and the laboratory that takes it is the one that runs it.
    it "takes a request that names nobody to perform the test" do
      post_request(service_request.except(:performer))

      expect(response).to have_http_status(:created)
      expect(Order.sole.receiving_lab_code).to be_nil
      expect(Order.sole.receiving_facility_code).to eq(api_client.facility_code)
    end

    it "answers an OperationOutcome, not the JSON API's envelope, when the key is unknown" do
      post "/fhir/r4/ServiceRequest", params: service_request.to_json,
                                      headers: { "Authorization" => "Bearer ssk_dev_deadbeef_x",
                                                 "Content-Type" => "application/fhir+json" }

      expect(response).to have_http_status(:unauthorized)
      body = response.parsed_body
      expect(body["resourceType"]).to eq("OperationOutcome")
      expect(body.dig("issue", 0, "code")).to eq("login")
      expect(body).not_to have_key("errors")
    end

    it "refuses a key without the scope to order" do
      readonly = issue_key(api_client: api_client, scopes: %w[orders:read]).last

      post "/fhir/r4/ServiceRequest", params: service_request.to_json,
                                      headers: { "Authorization" => "Bearer #{readonly}",
                                                 "Content-Type" => "application/fhir+json" }

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig("issue", 0, "details", "coding", 0, "code")).to eq("insufficient_scope")
    end

    it "refuses JSON it cannot parse" do
      post "/fhir/r4/ServiceRequest", params: "{ nope", headers: headers("Idempotency-Key" => SecureRandom.uuid)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["resourceType"]).to eq("OperationOutcome")
    end
  end

  describe "reading back" do
    let(:order) { create(:order, sending_facility_code: "HCM") }
    let!(:order_test) { create(:order_test, order: order, test_type: test_type) }

    it "answers the ServiceRequest by id" do
      get "/fhir/r4/ServiceRequest/#{order_test.uuid}", headers: headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["id"]).to eq(order_test.uuid)
      expect(body["status"]).to eq("active")
      expect(body.dig("code", "coding").map { |coding| coding["system"] })
        .to eq([ Fhir.code_system("test_types"), Fhir::LOINC_SYSTEM ])
    end

    # The native status is what tells a clinic whether to draw another tube. FHIR
    # calls a refused sample and a cancelled request both `revoked`.
    it "carries the native status in an extension" do
      order.transition_to!(Order::CANCELLED, actor: "teste")

      get "/fhir/r4/ServiceRequest/#{order_test.uuid}", headers: headers

      body = response.parsed_body
      expect(body["status"]).to eq("revoked")
      expect(body["extension"]).to include(
        a_hash_including("url" => Fhir.order_status_extension, "valueCode" => "cancelled")
      )
    end

    it "finds the tests of one sample by requisition" do
      create(:order_test, order: order)
      create(:order_test)

      get "/fhir/r4/ServiceRequest?requisition=#{order.tracking_number}", headers: headers

      body = response.parsed_body
      expect(body["resourceType"]).to eq("Bundle")
      expect(body["type"]).to eq("searchset")
      expect(body["total"]).to eq(2)
      expect(body["entry"].map { |entry| entry.dig("resource", "id") })
        .to match_array(order.order_tests.map(&:uuid))
    end

    it "finds them by the patient's national identifier" do
      patient = create(:patient, :identified)
      mine = create(:order_test, order: create(:order, patient: patient, sending_facility_code: "HCM"))

      get "/fhir/r4/ServiceRequest?patient.identifier=#{Fhir.national_id_system}|#{patient.national_id}",
          headers: headers

      expect(response.parsed_body["entry"].map { |entry| entry.dig("resource", "id") }).to eq([ mine.uuid ])
    end

    # A search is filtered, never refused: an empty bundle is a legitimate
    # answer. Naming another facility's resource outright is what is refused.
    it "leaves another facility's tests out of a search" do
      create(:order_test, order: create(:order, sending_facility_code: "HRQ"))

      get "/fhir/r4/ServiceRequest", headers: headers

      expect(response.parsed_body["entry"].map { |entry| entry.dig("resource", "id") }).to eq([ order_test.uuid ])
    end
  end
end
