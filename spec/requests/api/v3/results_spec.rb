# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GET /api/v3/results", mode: :local, type: :request do
  let(:api_client) { create(:api_client, facility_code: "HCM") }
  let(:credentials) { issue_key(api_client: api_client, scopes: %w[results:read]) }
  let(:token) { credentials.last }

  let(:indicator) { create(:indicator, name: "Hemoglobina") }

  def record_result(order: create(:order, sending_facility_code: "HCM"), value: "12.4", **options)
    TestResult.record!(
      order_test: create(:order_test, order: order),
      indicator: indicator,
      value: value,
      **options
    )
  end

  def get_results(bearer: token, **query)
    get "/api/v3/results", params: query, headers: auth_headers(bearer)
  end

  describe "polling with a cursor" do
    it "hands over everything recorded since the cursor, oldest first" do
      first = record_result(value: "12.4")
      second = record_result(value: "14.2")

      get_results(since: 0)

      expect(response).to have_http_status(:ok)

      data = response.parsed_body["data"]
      expect(data.map { |result| result["uuid"] }).to eq([ first.uuid, second.uuid ])
      expect(response.parsed_body.dig("meta", "next_cursor")).to eq(second.revision)
    end

    it "hands over nothing twice" do
      record_result

      get_results(since: 0)
      cursor = response.parsed_body.dig("meta", "next_cursor")

      get_results(since: cursor)

      expect(response.parsed_body["data"]).to be_empty
      expect(response.parsed_body.dig("meta", "next_cursor")).to eq(cursor)
    end

    it "carries the context a reading is useless without" do
      result = record_result

      get_results(since: 0)

      entry = response.parsed_body["data"].sole
      expect(entry["tracking_number"]).to eq(result.order_test.tracking_number)
      expect(entry["patient"]).to include("name" => result.order_test.order.patient.name)
      expect(entry["test_type"]).to include("national_code" => result.order_test.test_type.national_code)
      expect(entry["indicator"]).to include("national_code" => indicator.national_code)
    end

    it "says when there is more behind the page it just gave" do
      3.times { record_result }

      get_results(since: 0, limit: 2)

      expect(response.parsed_body["data"].length).to eq(2)
      expect(response.parsed_body.dig("meta", "has_more")).to be(true)

      get_results(since: response.parsed_body.dig("meta", "next_cursor"), limit: 2)

      expect(response.parsed_body["data"].length).to eq(1)
      expect(response.parsed_body.dig("meta", "has_more")).to be(false)
    end

    # A correction has to reach an EMR that already filed the wrong value, and
    # it reaches it twice over: the reading it holds is marked as superseded,
    # and the reading that supersedes it arrives behind.
    it "delivers a correction and the notice that the old reading was replaced" do
      order = create(:order, sending_facility_code: "HCM")
      order_test = create(:order_test, order: order)
      wrong = TestResult.record!(order_test: order_test, indicator: indicator, value: "12.4")

      get_results(since: 0)
      cursor = response.parsed_body.dig("meta", "next_cursor")

      right = TestResult.record!(order_test: order_test, indicator: indicator, value: "14.2")

      get_results(since: cursor)

      data = response.parsed_body["data"]
      expect(data.map { |result| result["uuid"] }).to eq([ wrong.uuid, right.uuid ])
      expect(data.first["replaced_by_uuid"]).to eq(right.uuid)
      expect(data.last["replaced_by_uuid"]).to be_nil
    end

    it "only shows a facility its own results" do
      mine = record_result
      record_result(order: create(:order, sending_facility_code: "XAI"))

      get_results(since: 0)

      expect(response.parsed_body["data"].map { |result| result["uuid"] }).to eq([ mine.uuid ])
    end

    it "narrows to one patient when asked" do
      patient = create(:patient, national_id: "110100234567A")
      wanted = record_result(order: create(:order, patient: patient, sending_facility_code: "HCM"))
      record_result

      get_results(since: 0, patient_national_id: "110100234567a")

      expect(response.parsed_body["data"].map { |result| result["uuid"] }).to eq([ wanted.uuid ])
    end

    it "answers 403 for a key that may not read results" do
      writer = issue_key(api_client: api_client, scopes: %w[orders:write])

      get_results(bearer: writer.last)

      expect(response).to have_http_status(:forbidden)
    end

    it "answers 401 without a key" do
      get "/api/v3/results"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v3/results/{uuid}/acknowledge" do
    def acknowledge(uuid, bearer: token)
      post "/api/v3/results/#{uuid}/acknowledge", headers: auth_headers(bearer)
    end

    it "records that the EMR has filed the reading" do
      result = record_result

      acknowledge(result.uuid)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "acknowledged_at")).to be_present
      expect(result.reload).to be_acknowledged
      expect(result.acknowledged_by).to eq(api_client.name)
    end

    # Confirming a reading must not move the cursor, or the EMR would be handed
    # its own confirmation on the next poll and confirm it again, for ever.
    it "does not move the cursor" do
      result = record_result

      expect { acknowledge(result.uuid) }.not_to change { result.reload.revision }

      get_results(since: result.revision)
      expect(response.parsed_body["data"]).to be_empty
    end

    # Filing a reading that has since been corrected is the mistake the whole
    # design exists to prevent.
    it "answers 409 for a reading that has been superseded" do
      order_test = create(:order_test, order: create(:order, sending_facility_code: "HCM"))
      wrong = TestResult.record!(order_test: order_test, indicator: indicator, value: "12.4")
      right = TestResult.record!(order_test: order_test, indicator: indicator, value: "14.2")

      acknowledge(wrong.uuid)

      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("conflict")
      expect(response.parsed_body.dig("errors", 0, "message")).to include(right.uuid)
      expect(wrong.reload).not_to be_acknowledged
    end

    it "answers 404 for a reading this node does not have" do
      acknowledge(SecureRandom.uuid)

      expect(response).to have_http_status(:not_found)
    end
  end
end
