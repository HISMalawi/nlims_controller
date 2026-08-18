# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Referência da API", type: :request do
  it "abre sem chave e sem sessão iniciada carregando a interface Scalar" do
    get "/api-docs"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("scalar")
    expect(response.body).to include("/api-docs.json")
  end

  it "serve o documento OpenAPI em JSON" do
    get "/api-docs.json"

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["openapi"]).to start_with("3.1")
    expect(response.parsed_body["paths"]).to be_present
    expect(response.parsed_body.dig("info", "version")).to eq(SislabSync.version)
  end

  it "serve o documento OpenAPI em YAML" do
    get "/api-docs.yaml"

    expect(response).to have_http_status(:ok)
    expect(YAML.safe_load(response.body).fetch("openapi")).to start_with("3.1")
  end

  # A team pointed at a laboratory node should not read about endpoints only the
  # capital answers, and go looking for routes that were never drawn here.
  it "mostra apenas o que este nó responde" do
    get "/api-docs.json"

    templates = response.parsed_body.fetch("paths").keys

    if SislabSync.local?
      expect(templates).to include("/api/v3/order-requests")
      expect(templates).not_to include("/api/v3/sync/events")
    else
      expect(templates).to include("/api/v3/sync/events")
      expect(templates).not_to include("/api/v3/order-requests")
    end
  end

  it "declara os âmbitos exigidos nas operações do documento" do
    get "/api-docs.json"

    changes_op = response.parsed_body.dig("paths", "/api/v3/dictionary/changes", "get")
    expect(changes_op["x-scope"]).to eq("dictionary:read")
  end
end
