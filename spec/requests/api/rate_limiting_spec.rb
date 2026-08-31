# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rate limiting", type: :request do
  # Time is held still: the window is bucketed by wall clock, so an example that
  # happened to straddle a minute boundary would see the counter reset and fail
  # for a reason that has nothing to do with rate limiting.
  around do |example|
    original = ENV.fetch("API_RATE_LIMIT_PER_MINUTE", nil)
    ENV["API_RATE_LIMIT_PER_MINUTE"] = "3"
    Rails.cache.clear
    freeze_time { example.run }
    ENV["API_RATE_LIMIT_PER_MINUTE"] = original
    Rails.cache.clear
  end

  let(:token) { issue_key(scopes: %w[orders:read]).last }

  it "allows requests up to the limit" do
    3.times do
      get "/spec_probe", headers: auth_headers(token)
      expect(response).to have_http_status(:ok)
    end
  end

  it "refuses the request after the limit with a retry hint" do
    4.times { get "/spec_probe", headers: auth_headers(token) }

    expect(response).to have_http_status(:too_many_requests)
    expect(response.parsed_body.dig("errors", 0, "code")).to eq("rate_limited")
    expect(response.headers["Retry-After"].to_i).to be_between(1, 60)
  end

  # One noisy integration must not spend another one's budget.
  it "counts each key separately" do
    other_token = issue_key(scopes: %w[orders:read]).last

    4.times { get "/spec_probe", headers: auth_headers(token) }
    expect(response).to have_http_status(:too_many_requests)

    get "/spec_probe", headers: auth_headers(other_token)
    expect(response).to have_http_status(:ok)
  end

  it "does not throttle the unauthenticated health endpoint" do
    10.times do
      get "/api/v3/health"
      expect(response).to have_http_status(:ok)
    end
  end
end
