# frozen_string_literal: true

require "rails_helper"

RSpec.describe "FHIR DiagnosticReport", mode: :local, type: :request do
  let(:token) { issue_key(api_client: create(:api_client, facility_code: "HCM"), scopes: %w[results:read]).last }
  let(:indicator) { create(:indicator, name: "Hemoglobina") }
  let(:order_test) do
    create(:order_test,
           order: create(:order, patient: create(:patient, :identified),
                                 sending_facility_code: "HCM", receiving_lab_code: "HCM-LAB"),
           test_type: create(:test_type, name: "Hemograma", loinc_code: "718-7"))
  end

  def order = order_test.order
  def patient = order.patient

  def headers = { "Authorization" => "Bearer #{token}" }

  def complete!
    order.transition_to!(Order::ACCEPTED, actor: "lab")
    order.transition_to!(Order::SPECIMEN_COLLECTED, actor: "lab")
    order.transition_to!(Order::IN_PROGRESS, actor: "lab")
    order_test.transition_to!(OrderTest::IN_PROGRESS, actor: "lab")
    order_test.transition_to!(OrderTest::COMPLETED, actor: "lab")
  end

  describe "reading one report" do
    before do
      TestResult.record!(order_test: order_test, indicator: indicator, value: "12.4", unit: "g/dL",
                         recorded_at: Time.current)
      complete!
    end

    it "is final once the test is, with the readings inlined" do
      get "/fhir/r4/DiagnosticReport/#{order_test.uuid}", headers: headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body

      expect(body["resourceType"]).to eq("DiagnosticReport")
      expect(body["status"]).to eq("final")
      expect(body["result"].length).to eq(1)
      expect(body["contained"].map { |resource| resource["resourceType"] }).to eq([ "Observation" ])
      expect(body["contained"].first["valueQuantity"]).to eq("value" => 12.4, "unit" => "g/dL")
    end

    it "names the tracking number and the laboratory that ran it" do
      get "/fhir/r4/DiagnosticReport/#{order_test.uuid}", headers: headers

      body = response.parsed_body
      expect(body["identifier"].first["value"]).to eq(order.tracking_number)
      expect(body.dig("performer", 0, "identifier", "value")).to eq("HCM-LAB")
      expect(body.dig("basedOn", 0, "reference")).to eq("ServiceRequest/#{order_test.uuid}")
    end

    # A correction does not reopen the test — that would make it look like a
    # second run — so `corrected` is the only place the report can say so.
    it "reports corrected when a reading was replaced after the test finished" do
      TestResult.record!(order_test: order_test, indicator: indicator, value: "14.1", unit: "g/dL",
                         recorded_at: Time.current)

      get "/fhir/r4/DiagnosticReport/#{order_test.uuid}", headers: headers

      body = response.parsed_body
      expect(body["status"]).to eq("corrected")
      # Only the reading that stands is in the report; the superseded one is
      # still on the Observation feed, marked entered-in-error.
      expect(body["result"].length).to eq(1)
      expect(body["contained"].first["valueQuantity"]["value"]).to eq(14.1)
    end
  end

  describe "a test that produced nothing" do
    # A rejected test that reported nothing is otherwise indistinguishable from
    # one still running, and the clinic has to know whether to draw again.
    it "says why, rather than looking like a test still in progress" do
      reason = create(:rejection_reason, name: "Amostra hemolisada")
      order.transition_to!(Order::ACCEPTED, actor: "lab")
      order_test
      order.reject!(reason: reason, actor: "lab")

      get "/fhir/r4/DiagnosticReport/#{order_test.uuid}", headers: headers

      body = response.parsed_body
      expect(body["status"]).to eq("cancelled")
      expect(body["conclusion"]).to eq("Amostra hemolisada")
      expect(body["result"]).to eq([])
    end

    it "is registered while nothing has been observed yet" do
      order_test

      get "/fhir/r4/DiagnosticReport/#{order_test.uuid}", headers: headers

      expect(response.parsed_body["status"]).to eq("registered")
    end
  end

  describe "searching" do
    it "finds every report on one sample by tracking number" do
      order_test
      create(:order_test, order: order)
      create(:order_test)

      get "/fhir/r4/DiagnosticReport?identifier=#{order.tracking_number}", headers: headers

      expect(response.parsed_body["total"]).to eq(2)
    end

    it "finds a patient's reports by national identifier" do
      order_test

      get "/fhir/r4/DiagnosticReport?patient.identifier=#{patient.national_id}", headers: headers

      expect(response.parsed_body["entry"].map { |entry| entry.dig("resource", "id") }).to eq([ order_test.uuid ])
    end

    it "leaves another facility's reports out" do
      order_test
      create(:order_test, order: create(:order, sending_facility_code: "HRQ"))

      get "/fhir/r4/DiagnosticReport", headers: headers

      expect(response.parsed_body["entry"].map { |entry| entry.dig("resource", "id") }).to eq([ order_test.uuid ])
    end
  end
end
