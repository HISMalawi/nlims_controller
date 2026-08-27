# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GET /api/v3/orders/{tracking_number}", mode: :local, type: :request do
  let(:api_client) { create(:api_client, facility_code: "HCM") }
  let(:credentials) { issue_key(api_client: api_client, scopes: %w[orders:read results:read]) }
  let(:token) { credentials.last }

  let(:order) { create(:order, sending_facility_code: "HCM") }

  def get_order(tracking_number: order.tracking_number, bearer: token)
    get "/api/v3/orders/#{tracking_number}", headers: auth_headers(bearer)
  end

  describe "the state of a sample" do
    it "reports the order and every test on it" do
      create(:order_test, order: order)
      create(:order_test, order: order).transition_to!(OrderTest::IN_PROGRESS)

      get_order

      expect(response).to have_http_status(:ok)

      data = response.parsed_body["data"]
      expect(data["tracking_number"]).to eq(order.tracking_number)
      expect(data["status"]).to eq(Order::REQUESTED)
      expect(data["tests"].map { |test| test["status"] })
        .to contain_exactly(OrderTest::PENDING, OrderTest::IN_PROGRESS)
    end

    it "names the patient and the dictionary items by code, never by id" do
      get_order

      data = response.parsed_body["data"]
      expect(data["patient"]).to include("name" => order.patient.name)
      expect(data["specimen_type"]).to include("national_code" => order.specimen_type.national_code)
      expect(response.body).not_to include('"id":')
    end

    it "leaves the readings out until they are asked for" do
      order_test = create(:order_test, order: order)
      TestResult.record!(order_test: order_test, indicator: create(:indicator), value: "12.4")

      get_order

      expect(response.parsed_body.dig("data", "tests", 0)).not_to have_key("results")
    end

    it "answers 404 for a number this node never issued" do
      get_order(tracking_number: "MZ-HCM-26229-9999")

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("not_found")
    end

    it "answers 401 without a key" do
      get "/api/v3/orders/#{order.tracking_number}"

      expect(response).to have_http_status(:unauthorized)
    end

    # Scope is checked before the sample is looked up, so a key that may not
    # read orders cannot learn which tracking numbers exist by watching for the
    # difference between 403 and 404.
    it "answers 403 rather than 404 for a key without the scope" do
      keyless = issue_key(api_client: api_client, scopes: %w[dictionary:read])

      get "/api/v3/orders/MZ-HCM-26229-9999", headers: auth_headers(keyless.last)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "the readings on a sample" do
    let(:order_test) { create(:order_test, order: order) }

    def get_results(bearer: token)
      get "/api/v3/orders/#{order.tracking_number}/results", headers: auth_headers(bearer)
    end

    it "reports every reading, per indicator" do
      indicator = create(:indicator, name: "Hemoglobina")
      TestResult.record!(order_test: order_test, indicator: indicator, value: "12.4", unit: "g/dL")

      get_results

      result = response.parsed_body.dig("data", "tests", 0, "results", 0)
      expect(result["value"]).to eq("12.4")
      expect(result["unit"]).to eq("g/dL")
      expect(result["indicator"]).to include("national_code" => indicator.national_code)
    end

    # A corrected reading and the one it replaced both travel, so an EMR that
    # filed the first can tell that it has been superseded and by which row.
    it "reports a correction alongside the reading it replaced" do
      indicator = create(:indicator, name: "Hemoglobina")
      TestResult.record!(order_test: order_test, indicator: indicator, value: "12.4")
      TestResult.record!(order_test: order_test, indicator: indicator, value: "14.2")

      get_results

      results = response.parsed_body.dig("data", "tests", 0, "results")
      expect(results.map { |result| result["value"] }).to eq(%w[12.4 14.2])
      expect(results.first["replaced_by_uuid"]).to eq(results.last["uuid"])
    end

    it "answers an order with no readings yet" do
      order_test

      get_results

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "tests", 0, "results")).to eq([])
    end

    it "answers 403 for a key that may see the order but not its readings" do
      orders_only = issue_key(api_client: api_client, scopes: %w[orders:read])

      get_results(bearer: orders_only.last)

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("insufficient_scope")
    end
  end
end
