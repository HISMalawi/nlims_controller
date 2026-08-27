# frozen_string_literal: true

require "rails_helper"

RSpec.describe "FHIR Patient and Specimen", mode: :local, type: :request do
  let(:api_client) { create(:api_client, facility_code: "HCM") }
  let(:token) { issue_key(api_client: api_client, scopes: %w[orders:read]).last }

  let(:patient) { create(:patient, :identified, name: "Ana Macuácua", sex: "F", phone: "+258840000000") }
  let(:specimen_type) { create(:specimen_type, name: "Sangue total") }
  let!(:order) do
    create(:order, patient: patient, specimen_type: specimen_type, sending_facility_code: "HCM",
                   collected_at: Time.zone.parse("2026-09-14 08:20"))
  end

  def headers = { "Authorization" => "Bearer #{token}" }

  describe "Patient" do
    it "answers the patient by uuid" do
      get "/fhir/r4/Patient/#{patient.uuid}", headers: headers

      body = response.parsed_body
      expect(body["resourceType"]).to eq("Patient")
      expect(body["gender"]).to eq("female")
      expect(body.dig("name", 0, "text")).to eq("Ana Macuácua")
      expect(body.dig("identifier", 0, "value")).to eq(patient.national_id)
      expect(body.dig("telecom", 0, "value")).to eq("+258840000000")
    end

    # A great many patients arrive without an identifier and one is never
    # invented, so the array is empty rather than carrying something an EMR
    # might match on.
    it "leaves the identifier out entirely for a patient who has none" do
      anonymous = create(:patient)
      create(:order, patient: anonymous, sending_facility_code: "HCM")

      get "/fhir/r4/Patient/#{anonymous.uuid}", headers: headers

      expect(response.parsed_body["identifier"]).to eq([])
    end

    it "finds a patient by national identifier" do
      get "/fhir/r4/Patient?identifier=#{Fhir.national_id_system}|#{patient.national_id}", headers: headers

      expect(response.parsed_body["entry"].map { |entry| entry.dig("resource", "id") }).to eq([ patient.uuid ])
    end

    # This is a laboratory node, not a patient registry. A key that can order
    # tests must not double as a way to enumerate the country's patients.
    it "answers nothing at all to a search with no identifier" do
      get "/fhir/r4/Patient", headers: headers

      expect(response.parsed_body["entry"]).to eq([])
    end

    it "does not answer for a patient this facility has no samples from" do
      theirs = create(:patient, :identified)
      create(:order, patient: theirs, sending_facility_code: "HRQ")

      get "/fhir/r4/Patient/#{theirs.uuid}", headers: headers

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body["resourceType"]).to eq("OperationOutcome")
    end
  end

  describe "Specimen" do
    # One order is one sample here, so the Specimen shares the order's uuid and
    # a client following ServiceRequest.specimen finds something at the far end.
    it "answers the sample under the order's uuid" do
      get "/fhir/r4/Specimen/#{order.uuid}", headers: headers

      body = response.parsed_body
      expect(body["resourceType"]).to eq("Specimen")
      expect(body["status"]).to eq("available")
      expect(body.dig("accessionIdentifier", "value")).to eq(order.tracking_number)
      expect(body.dig("type", "coding", 0, "code")).to eq(specimen_type.national_code)
      expect(body.dig("collection", "collectedDateTime")).to eq(order.collected_at.iso8601)
      expect(body.dig("subject", "reference")).to eq("Patient/#{patient.uuid}")
    end

    it "is unsatisfactory once the laboratory has refused it, and says why" do
      reason = create(:rejection_reason, name: "Amostra hemolisada")
      order.transition_to!(Order::ACCEPTED, actor: "lab")
      order.reject!(reason: reason, actor: "lab")

      get "/fhir/r4/Specimen/#{order.uuid}", headers: headers

      body = response.parsed_body
      expect(body["status"]).to eq("unsatisfactory")
      expect(body.dig("note", 0, "text")).to eq("Amostra hemolisada")
    end
  end
end
