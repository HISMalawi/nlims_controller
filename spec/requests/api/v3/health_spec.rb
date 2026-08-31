# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GET /api/v3/health", type: :request do
  it "reports which node this is, without a key" do
    get "/api/v3/health"

    expect(response).to have_http_status(:ok)

    body = response.parsed_body
    expect(body["data"]).to include(
      "mode" => SislabSync.mode,
      "node_code" => SislabSync.node_code,
      "version" => SislabSync.version
    )
    expect(body["errors"]).to eq([])
  end

  it "answers in the same envelope every endpoint uses" do
    get "/api/v3/health"

    expect(response.parsed_body.keys).to match_array(%w[data meta errors])
  end
end
