# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Idempotency", type: :request do
  let(:credentials) { issue_key(scopes: %w[orders:write]) }
  let(:token) { credentials.last }

  def post_probe(key:, body: { value: 1 })
    post "/spec_probe",
         params: body.to_json,
         headers: auth_headers(token).merge(
           "Idempotency-Key" => key,
           "Content-Type" => "application/json"
         )
  end

  it "requires the header on a creating request" do
    post "/spec_probe", headers: auth_headers(token)

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body.dig("errors", 0, "code")).to eq("idempotency_key_required")
  end

  it "creates once and replays the same answer on a retry" do
    post_probe(key: "abc-123")
    first_status = response.status
    first_body = response.body

    expect(first_status).to eq(201)

    post_probe(key: "abc-123")

    expect(response.status).to eq(first_status)
    expect(response.body).to eq(first_body)
    expect(response.headers["Idempotent-Replay"]).to eq("true")
  end

  it "stores exactly one record for a repeated key" do
    expect do
      post_probe(key: "abc-123")
      post_probe(key: "abc-123")
      post_probe(key: "abc-123")
    end.to change(IdempotentRequest, :count).by(1)
  end

  # Reusing a key with a different payload is a client bug. Replaying the first
  # answer would hide it, so it is refused instead.
  it "refuses the same key with a different body" do
    post_probe(key: "abc-123", body: { value: 1 })
    post_probe(key: "abc-123", body: { value: 2 })

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.dig("errors", 0, "code")).to eq("idempotency_key_reused")
  end

  it "keeps keys separate between clients" do
    post_probe(key: "shared")

    _other_key, other_token = issue_key(scopes: %w[orders:write])
    post "/spec_probe",
         params: { value: 1 }.to_json,
         headers: auth_headers(other_token).merge(
           "Idempotency-Key" => "shared",
           "Content-Type" => "application/json"
         )

    expect(response).to have_http_status(:created)
    expect(response.headers["Idempotent-Replay"]).to be_nil
  end
end
