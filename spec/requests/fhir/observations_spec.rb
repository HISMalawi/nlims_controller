# frozen_string_literal: true

require "rails_helper"

RSpec.describe "FHIR Observation", mode: :local, type: :request do
  let(:token) do
    issue_key(api_client: create(:api_client, facility_code: "HCM", name: "EMR do HCM"), scopes: %w[results:read]).last
  end
  let(:indicator) { create(:indicator, name: "Hemoglobina", unit: "g/dL", value_type: "Numeric", loinc_code: "718-7") }
  let(:order_test) do
    patient = create(:patient, :identified, name: "Ana Macuácua", sex: "F", birthdate: Date.new(1991, 4, 12))

    create(:order_test, order: create(:order, patient: patient, sending_facility_code: "HCM",
                                              collected_at: Time.zone.parse("2026-09-14 08:20")))
  end

  def order = order_test.order
  def patient = order.patient

  def headers = { "Authorization" => "Bearer #{token}" }

  def record(value, **options)
    TestResult.record!(order_test: order_test, indicator: indicator, value: value,
                       unit: "g/dL", recorded_by: "tec.mabjaia", **options)
  end

  describe "one reading" do
    let!(:result) { record("12.4") }

    it "answers a numeric indicator as a quantity" do
      get "/fhir/r4/Observation/#{result.uuid}", headers: headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body

      expect(body["resourceType"]).to eq("Observation")
      expect(body["status"]).to eq("final")
      expect(body["valueQuantity"]).to eq("value" => 12.4, "unit" => "g/dL")
      expect(body["effectiveDateTime"]).to eq(order.collected_at.iso8601)
      expect(body["issued"]).to eq(result.recorded_at.iso8601)
    end

    # The dictionary's units are the laboratory's own strings, not UCUM. Saying
    # they were UCUM would invite a client to convert between two units that
    # only look like the ones it knows.
    it "does not claim the unit is UCUM" do
      get "/fhir/r4/Observation/#{result.uuid}", headers: headers

      expect(response.parsed_body["valueQuantity"]).not_to have_key("system")
    end

    it "carries the national code first and LOINC alongside it" do
      get "/fhir/r4/Observation/#{result.uuid}", headers: headers

      codings = response.parsed_body.dig("code", "coding")
      expect(codings.map { |coding| coding["system"] })
        .to eq([ Fhir.code_system("indicators"), Fhir::LOINC_SYSTEM ])
      expect(codings.last["code"]).to eq("718-7")
    end

    # A reading that is not a number must never arrive as one: a client that
    # receives valueQuantity is entitled to do arithmetic on it.
    it "sends a reading that does not parse as a string" do
      qualitative = create(:indicator, value_type: "Numeric", name: "Carga viral")
      row = TestResult.record!(order_test: order_test, indicator: qualitative, value: "<40",
                               recorded_at: Time.current)

      get "/fhir/r4/Observation/#{row.uuid}", headers: headers

      expect(response.parsed_body["valueString"]).to eq("<40")
      expect(response.parsed_body).not_to have_key("valueQuantity")
    end

    it "narrows the reference range to this patient" do
      create(:indicator_range, indicator: indicator, sex: "F", age_min: 15, age_max: 60,
                               range_lower: 12.0, range_upper: 16.0)
      create(:indicator_range, indicator: indicator, sex: "M", age_min: 15, age_max: 60,
                               range_lower: 13.0, range_upper: 17.0)

      get "/fhir/r4/Observation/#{result.uuid}", headers: headers

      ranges = response.parsed_body["referenceRange"]
      expect(ranges.length).to eq(1)
      expect(ranges.first.dig("low", "value")).to eq(12.0)
      expect(ranges.first.dig("high", "value")).to eq(16.0)
    end
  end

  describe "corrections" do
    let!(:wrong) { record("12.4") }
    let!(:right) { record("14.1") }

    # This is the whole reason results are never rewritten. A client that filed
    # the wrong value has to be told to disregard it, and told what replaced it.
    it "marks the superseded reading entered-in-error and names its replacement" do
      get "/fhir/r4/Observation/#{wrong.uuid}", headers: headers

      body = response.parsed_body
      expect(body["status"]).to eq("entered-in-error")
      expect(body["extension"]).to include(
        a_hash_including("url" => Fhir.url("StructureDefinition/replaced-by"), "valueString" => right.uuid)
      )
    end

    it "leaves the replacement final" do
      get "/fhir/r4/Observation/#{right.uuid}", headers: headers

      expect(response.parsed_body["status"]).to eq("final")
    end
  end

  describe "the feed" do
    it "answers everything after the cursor, oldest revision first" do
      first = record("12.4")
      second = TestResult.record!(order_test: create(:order_test, order: order), indicator: create(:indicator),
                                  value: "5.1", recorded_at: Time.current)

      get "/fhir/r4/Observation?_since=#{first.revision - 1}", headers: headers

      ids = response.parsed_body["entry"].map { |entry| entry.dig("resource", "id") }
      expect(ids).to eq([ first.uuid, second.uuid ])
    end

    it "hands back nothing when the cursor is already at the end" do
      record("12.4")

      get "/fhir/r4/Observation?_since=#{TestResult.cursor}", headers: headers

      expect(response.parsed_body["entry"]).to eq([])
      expect(response.parsed_body["link"].map { |link| link["relation"] }).to eq([ "self" ])
    end

    # The cursor is a revision from a locked counter, not a timestamp, so a
    # client that follows the links can move it and never look back.
    it "offers a next link carrying the revision it stopped on" do
      3.times { |n| record("1#{n}.0") }

      get "/fhir/r4/Observation?_count=2", headers: headers

      links = response.parsed_body["link"].index_by { |link| link["relation"] }
      expect(links).to have_key("next")

      last_revision = response.parsed_body["entry"].last.dig("resource", "meta", "versionId").to_i
      expect(links["next"]["url"]).to include("_since=#{last_revision}")

      get links["next"]["url"], headers: headers
      expect(response.parsed_body["entry"].length).to eq(1)
    end

    # A correction moves twice: once when the old row is marked, once when the
    # new row is written. Both have to reach a client that only ever polls.
    it "carries corrections to a client that has already seen the original" do
      original = record("12.4")
      cursor = TestResult.cursor
      correction = record("14.1")

      get "/fhir/r4/Observation?_since=#{cursor}", headers: headers

      entries = response.parsed_body["entry"].map { |entry| entry["resource"] }
      expect(entries.map { |resource| resource["id"] }).to contain_exactly(original.uuid, correction.uuid)
      expect(entries.find { |resource| resource["id"] == original.uuid }["status"]).to eq("entered-in-error")
    end

    it "leaves another facility's readings out" do
      mine = record("12.4")
      TestResult.record!(order_test: create(:order_test, order: create(:order, sending_facility_code: "HRQ")),
                         indicator: create(:indicator), value: "9.9", recorded_at: Time.current)

      get "/fhir/r4/Observation", headers: headers

      expect(response.parsed_body["entry"].map { |entry| entry.dig("resource", "id") }).to eq([ mine.uuid ])
    end

    it "filters by the patient's national identifier" do
      mine = record("12.4")
      TestResult.record!(order_test: create(:order_test, order: create(:order, sending_facility_code: "HCM")),
                         indicator: create(:indicator), value: "9.9", recorded_at: Time.current)

      get "/fhir/r4/Observation?patient.identifier=#{patient.national_id}", headers: headers

      expect(response.parsed_body["entry"].map { |entry| entry.dig("resource", "id") }).to eq([ mine.uuid ])
    end
  end

  describe "$acknowledge" do
    let!(:result) { record("12.4") }

    it "records that the EMR filed the reading" do
      post "/fhir/r4/Observation/#{result.uuid}/$acknowledge", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["extension"]).to include(
        a_hash_including("url" => Fhir.url("StructureDefinition/acknowledged-at"))
      )
      expect(result.reload.acknowledged_by).to eq("EMR do HCM")
    end

    # Filing a reading that has since been corrected is the mistake the whole
    # replacement design exists to prevent.
    it "refuses to confirm a reading that has been superseded, naming the replacement" do
      correction = record("14.1")

      post "/fhir/r4/Observation/#{result.uuid}/$acknowledge", headers: headers

      expect(response).to have_http_status(:conflict)
      issue = response.parsed_body.dig("issue", 0)
      expect(issue["code"]).to eq("conflict")
      expect(issue.dig("details", "text")).to include(correction.uuid)
      expect(result.reload).not_to be_acknowledged
    end

    it "refuses another facility's reading" do
      theirs = TestResult.record!(order_test: create(:order_test, order: create(:order, sending_facility_code: "HRQ")),
                                  indicator: create(:indicator), value: "9.9", recorded_at: Time.current)

      post "/fhir/r4/Observation/#{theirs.uuid}/$acknowledge", headers: headers

      expect(response).to have_http_status(:forbidden)
    end
  end
end
