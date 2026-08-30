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
    it "hands over the orders raised at this unit, oldest first" do
      first = create(:order, receiving_lab_code: "HCM-LAB")
      second = create(:order, receiving_lab_code: "HCM-LAB")

      get_pending(since: 0)

      expect(response).to have_http_status(:ok)

      data = response.parsed_body["data"]
      expect(data.map { |order| order["tracking_number"] })
        .to eq([ first.tracking_number, second.tracking_number ])
      expect(response.parsed_body.dig("meta", "next_cursor")).to eq(second.revision)
      expect(response.parsed_body.dig("meta", "facility_code")).to eq("HCM")
    end

    # The node is the unit, not one bench in it: a sample another unit is
    # working is nothing to do with this installation, however it is addressed.
    it "leaves another unit's work alone" do
      mine = create(:order, receiving_lab_code: "HCM-LAB")
      create(:order, receiving_facility_code: "XAI", receiving_lab_code: "XAI-LAB")

      get_pending(since: 0)

      expect(response.parsed_body["data"].map { |order| order["tracking_number"] })
        .to eq([ mine.tracking_number ])
    end

    # A sample keeps the code it was written with. A laboratory registered here
    # takes samples under its LIS code and, from the day the capital names it,
    # under the national one — and both are its work. Without this, the day the
    # capital catches up is the day a bench's older samples vanish from its
    # queue.
    it "finds the bench's work under every code it has been written as" do
      lab = Lab.register_local!(source_code: "LAB07", facility_code: "HCM", name: "Bioquímica")
      early = create(:order, receiving_lab_code: "LAB07")
      lab.update!(national_code: "MOZ-LAB-0042")
      later = create(:order, receiving_lab_code: "MOZ-LAB-0042")

      get_pending(since: 0, lab_code: "MOZ-LAB-0042")

      expect(response.parsed_body["data"].map { |order| order["tracking_number"] })
        .to eq([ early.tracking_number, later.tracking_number ])
    end

    # An mLab instance polling for one of its benches wants that bench's work
    # and whatever is still going spare, and not the bench next door's.
    it "narrows to one bench when asked, keeping what nobody has claimed" do
      mine = create(:order, receiving_lab_code: "HCM-LAB")
      unclaimed = create(:order, receiving_lab_code: nil)
      create(:order, receiving_lab_code: "HCM-MICRO")

      get_pending(since: 0, lab_code: "HCM-LAB")

      expect(response.parsed_body["data"].map { |order| order["tracking_number"] })
        .to eq([ mine.tracking_number, unclaimed.tracking_number ])
      expect(response.parsed_body.dig("meta", "lab_code")).to eq("HCM-LAB")
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

  # The key used to be checked against the laboratory in the query, and a
  # mismatch answered 403. A node is now a laboratory, and holds only the
  # samples it has a hand in, so the queue a key can reach is the node's own
  # either way.
  describe "the laboratory in the query" do
    it "hands over the queue for the laboratory it was asked about" do
      get_pending(since: 0, lab_code: "HCM-MICRO")

      expect(response).to have_http_status(:ok)
    end

    # One mLab instance holds several laboratories under one key, so which of
    # them is asking is its business and not the key's. Leaving it out is the
    # normal thing to do, not an omission to be refused.
    it "gives the whole unit when no laboratory is named" do
      bioq = create(:order, receiving_lab_code: "HCM-LAB")
      micro = create(:order, receiving_lab_code: "HCM-MICRO")

      get_pending(since: 0)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].map { |order| order["tracking_number"] })
        .to eq([ bioq.tracking_number, micro.tracking_number ])
      expect(response.parsed_body.dig("meta", "lab_code")).to be_nil
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
