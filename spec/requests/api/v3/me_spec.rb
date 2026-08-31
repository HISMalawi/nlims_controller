# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GET /api/v3/me", type: :request do
  it "tells an integrator what their key is and what it may do" do
    client = create(:api_client, :sislab, name: "SISLAB HCM", facility_code: "HCM", lab_code: "HCM-LAB-BIOQ")
    key, token = issue_key(api_client: client, scopes: %w[orders:read results:write])

    get "/api/v3/me", headers: auth_headers(token)

    expect(response).to have_http_status(:ok)

    data = response.parsed_body["data"]
    expect(data["client"]).to include(
      "uuid" => client.uuid,
      "name" => "SISLAB HCM",
      "kind" => "sislab",
      "facility_code" => "HCM",
      "lab_code" => "HCM-LAB-BIOQ"
    )
    expect(data["key"]).to include("uuid" => key.uuid, "scopes" => %w[orders:read results:write])
    expect(data["node"]).to include("mode" => SislabSync.mode, "node_code" => SislabSync.node_code)
  end

  it "never echoes the secret back" do
    _key, token = issue_key

    get "/api/v3/me", headers: auth_headers(token)

    expect(response.body).not_to include(token)
  end

  # Identity is what an integrator checks when nothing else works, so it must
  # not itself need a scope.
  it "needs no particular scope" do
    _key, token = issue_key(scopes: [])

    get "/api/v3/me", headers: auth_headers(token)

    expect(response).to have_http_status(:ok)
  end

  it "still needs a key" do
    get "/api/v3/me"

    expect(response).to have_http_status(:unauthorized)
  end
end
