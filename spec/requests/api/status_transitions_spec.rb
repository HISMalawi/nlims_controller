# frozen_string_literal: true

require "rails_helper"

# S6 asks that an illegal transition be refused with 422 rather than written.
# The endpoints that move an order arrive in S7 and S8, so this goes through the
# probe — the same BaseController, the same error envelope those endpoints will
# inherit.
RSpec.describe "Status transitions over the API", type: :request do
  let(:credentials) { issue_key(scopes: %w[results:write]) }
  let(:token) { credentials.last }
  let(:order) { create(:order) }

  def patch_status(status, tracking_number: order.tracking_number, **params)
    patch "/spec_probe/orders/#{tracking_number}",
          params: { status: status, **params }.to_json,
          headers: auth_headers(token).merge("Content-Type" => "application/json")
  end

  it "accepts a transition the machine allows and returns the new state with its history" do
    patch_status(Order::ACCEPTED, reason: "amostra recebida")

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "status")).to eq(Order::ACCEPTED)

    history = response.parsed_body.dig("data", "history")
    expect(history.map { |event| event["to_status"] }).to eq([ Order::REQUESTED, Order::ACCEPTED ])
    expect(history.last["actor"]).to eq(credentials.first.api_client.name)
  end

  it "refuses an illegal transition with 422 and leaves the order where it was" do
    patch_status(Order::COMPLETED)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.dig("errors", 0, "code")).to eq("unprocessable")
    expect(response.parsed_body.dig("errors", 0, "field")).to eq("status")
    expect(response.parsed_body.dig("errors", 0, "message")).to include("requested to completed")

    expect(order.reload.status).to eq(Order::REQUESTED)
  end

  it "writes no history for a transition it refused" do
    order # registered before the count is taken; being created is itself an event

    expect { patch_status(Order::IN_PROGRESS) }.not_to change(StatusEvent, :count)
  end

  it "refuses a status nobody defined" do
    patch_status("em_ferias")

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "still answers 404 for a tracking number this node has never issued" do
    patch_status(Order::ACCEPTED, tracking_number: "MZ-HCM-26229-9999")

    expect(response).to have_http_status(:not_found)
  end

  it "refuses a key without the scope to publish states" do
    credentials = issue_key(scopes: %w[orders:read])

    patch "/spec_probe/orders/#{order.tracking_number}",
          params: { status: Order::ACCEPTED }.to_json,
          headers: auth_headers(credentials.last).merge("Content-Type" => "application/json")

    expect(response).to have_http_status(:forbidden)
  end
end
