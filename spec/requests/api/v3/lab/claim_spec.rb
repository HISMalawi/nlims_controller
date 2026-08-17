# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /api/v3/lab/orders/{tn}/claim", mode: :local, type: :request do
  let(:api_client) { create(:api_client, :sislab, facility_code: "HCM", lab_code: "HCM-LAB") }
  let(:credentials) { issue_key(api_client: api_client, scopes: %w[orders:read]) }
  let(:token) { credentials.last }

  let(:order) { create(:order, receiving_lab_code: "HCM-LAB") }

  def claim(tracking_number: order.tracking_number, bearer: token)
    post "/api/v3/lab/orders/#{tracking_number}/claim", headers: auth_headers(bearer)
  end

  it "takes the sample and accepts it in one movement" do
    claim

    expect(response).to have_http_status(:ok)

    data = response.parsed_body["data"]
    expect(data["status"]).to eq(Order::ACCEPTED)
    expect(data["claimed_by_lab_code"]).to eq("HCM-LAB")
    expect(data["claimed_at"]).to be_present
  end

  it "leaves the entry in the history an operator would look for" do
    claim

    event = order.own_status_events.last
    expect(event.to_status).to eq(Order::ACCEPTED)
    expect(event.actor).to eq(api_client.name)
    expect(event.reason).to include("HCM-LAB")
  end

  it "moves the order, so the laboratory sees it again on its next poll" do
    expect { claim }.to change { order.reload.revision }
  end

  describe "when two laboratories want the same sample" do
    it "answers 409 to the second, naming who has it" do
      claim
      claim

      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("conflict")
      expect(response.parsed_body.dig("errors", 0, "message")).to include("HCM-LAB")
    end

    it "leaves the first claim standing" do
      claim
      claimed_at = order.reload.claimed_at

      claim

      expect(order.reload.claimed_at).to eq(claimed_at)
      expect(order.status).to eq(Order::ACCEPTED)
    end
  end

  it "answers 404 for a number this node never issued" do
    claim(tracking_number: "MZ-HCM-26229-9999")

    expect(response).to have_http_status(:not_found)
  end

  it "refuses to let one laboratory take another's sample" do
    other = create(:order, receiving_lab_code: "XAI-LAB")

    claim(tracking_number: other.tracking_number)

    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body.dig("errors", 0, "code")).to eq("lab_mismatch")
    expect(other.reload).not_to be_claimed
  end

  # Claiming is accepting, and a sample that has been cancelled cannot be
  # accepted. The claim has to come off with the refused transition.
  it "does not hold a sample it could not accept" do
    order.transition_to!(Order::CANCELLED)

    claim

    expect(response).to have_http_status(:unprocessable_content)
    expect(order.reload).not_to be_claimed
  end
end
