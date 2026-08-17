# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GET /api/v3/lab/pending-orders", mode: :local, type: :request do
  let(:api_client) { create(:api_client, :sislab, facility_code: "HCM", lab_code: "HCM-LAB") }
  let(:credentials) { issue_key(api_client: api_client, scopes: %w[orders:read]) }
  let(:token) { credentials.last }

  def get_pending(bearer: token, **query)
    get "/api/v3/lab/pending-orders", params: query, headers: auth_headers(bearer)
  end

  describe "pulling the work" do
    it "hands over the orders addressed to this laboratory, oldest first" do
      first = create(:order, receiving_lab_code: "HCM-LAB")
      second = create(:order, receiving_lab_code: "HCM-LAB")

      get_pending(since: 0)

      expect(response).to have_http_status(:ok)

      data = response.parsed_body["data"]
      expect(data.map { |order| order["tracking_number"] })
        .to eq([ first.tracking_number, second.tracking_number ])
      expect(response.parsed_body.dig("meta", "next_cursor")).to eq(second.revision)
      expect(response.parsed_body.dig("meta", "lab_code")).to eq("HCM-LAB")
    end

    it "leaves another laboratory's work alone" do
      mine = create(:order, receiving_lab_code: "HCM-LAB")
      create(:order, receiving_lab_code: "XAI-LAB")

      get_pending(since: 0)

      expect(response.parsed_body["data"].map { |order| order["tracking_number"] })
        .to eq([ mine.tracking_number ])
    end

    it "carries the tests, the patient and the sample the laboratory needs" do
      order = create(:order, receiving_lab_code: "HCM-LAB")
      order_test = create(:order_test, order: order)

      get_pending(since: 0)

      entry = response.parsed_body["data"].sole
      expect(entry["patient"]).to include("name" => order.patient.name)
      expect(entry["specimen_type"]).to include("national_code" => order.specimen_type.national_code)
      expect(entry["tests"].sole["test_type"])
        .to include("national_code" => order_test.test_type.national_code)
    end

    it "hands over nothing twice" do
      create(:order, receiving_lab_code: "HCM-LAB")

      get_pending(since: 0)
      cursor = response.parsed_body.dig("meta", "next_cursor")

      get_pending(since: cursor)

      expect(response.parsed_body["data"]).to be_empty
      expect(response.parsed_body.dig("meta", "next_cursor")).to eq(cursor)
    end

    it "brings an order back when it changes" do
      order = create(:order, receiving_lab_code: "HCM-LAB")

      get_pending(since: 0)
      cursor = response.parsed_body.dig("meta", "next_cursor")

      order.transition_to!(Order::CANCELLED, actor: "emr", reason: "doente foi embora")

      get_pending(since: cursor)

      entry = response.parsed_body["data"].sole
      expect(entry["tracking_number"]).to eq(order.tracking_number)
      expect(entry["status"]).to eq(Order::CANCELLED)
    end

    # A laboratory that only saw open orders would never learn that a sample it
    # is working on was cancelled at the clinic.
    it "does not hide an order because it has finished" do
      order = create(:order, receiving_lab_code: "HCM-LAB")
      order.transition_to!(Order::CANCELLED)

      get_pending(since: 0)

      expect(response.parsed_body["data"].sole["status"]).to eq(Order::CANCELLED)
    end

    it "says when there is more behind the page it just gave" do
      3.times { create(:order, receiving_lab_code: "HCM-LAB") }

      get_pending(since: 0, limit: 2)

      expect(response.parsed_body["data"].length).to eq(2)
      expect(response.parsed_body.dig("meta", "has_more")).to be(true)

      get_pending(since: response.parsed_body.dig("meta", "next_cursor"), limit: 2)

      expect(response.parsed_body.dig("meta", "has_more")).to be(false)
    end
  end

  describe "the coincidence rule between the key and the resource" do
    it "refuses to hand over another laboratory's queue" do
      get_pending(since: 0, lab_code: "XAI-LAB")

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("lab_mismatch")
    end

    it "accepts the laboratory the key already names" do
      get_pending(since: 0, lab_code: "HCM-LAB")

      expect(response).to have_http_status(:ok)
    end

    it "asks for a laboratory when the key does not name one" do
      unpinned = issue_key(api_client: create(:api_client, :node), scopes: %w[orders:read])

      get_pending(since: 0, bearer: unpinned.last)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("errors", 0, "field")).to eq("lab_code")
    end

    it "answers 401 without a key" do
      get "/api/v3/lab/pending-orders"

      expect(response).to have_http_status(:unauthorized)
    end

    it "answers 403 for a key that may not read orders" do
      writer = issue_key(api_client: api_client, scopes: %w[results:write])

      get_pending(since: 0, bearer: writer.last)

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("insufficient_scope")
    end
  end
end
