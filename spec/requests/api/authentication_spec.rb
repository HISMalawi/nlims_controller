# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API key authentication", type: :request do
  describe "without a usable key" do
    it "refuses a request with no Authorization header" do
      get "/spec_probe"

      expect(response).to have_http_status(:unauthorized)
      expect(error_code).to eq("unauthenticated")
    end

    it "refuses a header that is not a bearer token" do
      get "/spec_probe", headers: { "Authorization" => "Token abc" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "refuses an unknown token" do
      get "/spec_probe", headers: auth_headers("ssk_dev_zzzzzzzz_#{'a' * 32}")

      expect(response).to have_http_status(:unauthorized)
    end

    it "stops a revoked key on the very next request" do
      key, token = issue_key

      get "/spec_probe", headers: auth_headers(token)
      expect(response).to have_http_status(:ok)

      key.revoke!

      get "/spec_probe", headers: auth_headers(token)
      expect(response).to have_http_status(:unauthorized)
    end

    # A probe must not be able to tell "no such key" from "revoked" from
    # "disabled client".
    it "answers every failure with the same code" do
      revoked, revoked_token = issue_key
      revoked.revoke!
      _expired, expired_token = issue_key(expires_at: 1.minute.ago)

      [ "ssk_dev_zzzzzzzz_#{'a' * 32}", revoked_token, expired_token ].each do |token|
        get "/spec_probe", headers: auth_headers(token)
        expect(error_code).to eq("unauthenticated")
      end
    end
  end

  describe "with a usable key" do
    it "lets the request through and records the use" do
      key, token = issue_key

      get "/spec_probe", headers: auth_headers(token)

      expect(response).to have_http_status(:ok)
      expect(key.reload.last_used_at).to be_present
    end
  end

  describe "scopes" do
    it "refuses a key that does not carry the scope" do
      _key, token = issue_key(scopes: %w[dictionary:read])

      get "/spec_probe", headers: auth_headers(token)

      expect(response).to have_http_status(:forbidden)
      expect(error_code).to eq("insufficient_scope")
    end

    it "allows a key that carries it" do
      _key, token = issue_key(scopes: %w[orders:read])

      get "/spec_probe", headers: auth_headers(token)

      expect(response).to have_http_status(:ok)
    end

    it "separates read from write" do
      _key, token = issue_key(scopes: %w[orders:read])

      post "/spec_probe", headers: auth_headers(token).merge("Idempotency-Key" => "k1")

      expect(error_code).to eq("insufficient_scope")
    end
  end

  # These used to compare the facility and laboratory codes in the request
  # against the ones stored on the key, and answer 403 when they differed. On a
  # node that is itself a laboratory there is nothing left to compare: the key
  # inherits its codes from the node, and the intake uses the node's own rather
  # than whatever the payload claims. What the comparison did in the field was
  # refuse integrations over a code typed into a form once and never looked at.
  describe "facility and lab codes in a request" do
    it "answers a request naming another facility, using its own" do
      client = create(:api_client, facility_code: "HCM")
      _key, token = issue_key(api_client: client)

      get "/spec_probe/facility/QUELIMANE", headers: auth_headers(token)

      expect(response).to have_http_status(:ok)
    end

    it "answers a request naming another laboratory" do
      client = create(:api_client, :sislab, lab_code: "HCM-LAB-BIOQ")
      _key, token = issue_key(api_client: client)

      get "/spec_probe/lab/HCM-LAB-MICRO", headers: auth_headers(token)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "the error envelope" do
    it "carries a stable code, a message and the standard shape" do
      get "/spec_probe"

      body = response.parsed_body
      expect(body.keys).to match_array(%w[data meta errors])
      expect(body["data"]).to be_nil
      expect(body["errors"].first).to include("code" => "unauthenticated")
      expect(body["errors"].first["message"]).to be_present
    end

    it "turns a missing record into a 404 with a code" do
      _key, token = issue_key

      get "/spec_probe/boom", headers: auth_headers(token)

      expect(response).to have_http_status(:not_found)
      expect(error_code).to eq("not_found")
    end
  end

  def error_code
    response.parsed_body.dig("errors", 0, "code")
  end
end
