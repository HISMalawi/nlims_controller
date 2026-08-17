# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Clientes e chaves na interface", type: :request do
  describe "quem pode entrar aqui" do
    it "não é um operador comum" do
      sign_in_as

      get api_clients_path

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to be_present
    end

    it "é um administrador" do
      sign_in_as :admin

      get api_clients_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "os clientes" do
    before { sign_in_as :admin }

    it "cria um cliente" do
      post api_clients_path, params: {
        api_client: { name: "EMR do HCM", kind: "emr", facility_code: "HCM", active: "1" }
      }

      client = ApiClient.find_by(name: "EMR do HCM")
      expect(client).to be_present
      expect(response).to redirect_to(api_client_path(client))
    end

    it "recusa um cliente EMR sem unidade sanitária" do
      post api_clients_path, params: { api_client: { name: "EMR sem casa", kind: "emr", active: "1" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(ApiClient.count).to be_zero
    end

    it "não deixa mudar o tipo depois de criado, porque isso re-escoparia as chaves já emitidas" do
      client = create(:api_client, kind: "emr")

      patch api_client_path(client), params: { api_client: { name: "Outro nome", kind: "node" } }

      expect(client.reload.kind).to eq("emr")
      expect(client.name).to eq("Outro nome")
    end

    it "retira um cliente marcando-o inactivo em vez de o apagar" do
      client = create(:api_client)

      patch api_client_path(client), params: { api_client: { name: client.name, active: "0" } }

      expect(client.reload).not_to be_active
      expect(ApiClient.count).to eq(1)
    end
  end

  describe "as chaves" do
    before { sign_in_as :admin }

    let(:client) { create(:api_client) }

    it "mostra o segredo uma única vez, e mais nunca" do
      post api_client_api_keys_path(client), params: { scopes: [ "orders:write", "results:read" ] }

      expect(response).to have_http_status(:created)

      token = response.body[/ssk_#{ApiKey.environment_segment}_[a-z0-9]{8}_[A-Za-z0-9]{32}/]
      expect(token).to be_present

      key = client.api_keys.sole
      expect(ApiKey.authenticate(token)).to eq(key)

      # Nowhere else on the interface, because nowhere else has it.
      get api_client_path(client)
      expect(response.body).not_to include(token)
    end

    it "regista quem a emitiu" do
      user = create(:user, :admin, name: "Ana Machava", email: "ana@hcm.gov.mz")
      sign_in(user)

      post api_client_api_keys_path(client), params: { scopes: [ "orders:read" ] }

      expect(client.api_keys.sole.issued_by).to eq("Ana Machava <ana@hcm.gov.mz>")
    end

    it "recusa emitir uma chave sem permissões" do
      post api_client_api_keys_path(client), params: { scopes: [] }

      expect(response).to have_http_status(:unprocessable_content)
      expect(client.api_keys).to be_empty
    end

    it "ignora permissões que não existem" do
      post api_client_api_keys_path(client), params: { scopes: [ "orders:read", "tudo:tudo" ] }

      expect(client.api_keys.sole.scopes).to eq([ "orders:read" ])
    end

    it "revoga uma chave, e a chave deixa de servir" do
      key, token = ApiKey.issue!(api_client: client, scopes: [ "orders:read" ])

      delete api_client_api_key_path(client, key)

      expect(response).to redirect_to(api_client_path(client))
      expect(key.reload).to be_revoked
      expect(ApiKey.authenticate(token)).to be_nil
    end

    it "roda uma chave sem cortar o cliente que ainda usa a antiga" do
      old, old_token = ApiKey.issue!(api_client: client, scopes: [ "orders:read", "results:read" ])

      post rotate_api_client_api_key_path(client, old)

      expect(response).to have_http_status(:created)

      new_key = client.api_keys.where.not(id: old.id).sole
      expect(new_key.scopes).to eq(old.scopes)
      expect(old.reload).not_to be_revoked
      expect(ApiKey.authenticate(old_token)).to eq(old)
    end
  end

  describe "a auditoria" do
    before { sign_in_as :admin }

    it "lista os pedidos e destaca os recusados" do
      client = create(:api_client)
      RequestAudit.create!(api_client: client, request_method: "GET", path: "/api/v3/results",
                           status: 200, created_at: Time.current)
      RequestAudit.create!(api_client: client, request_method: "POST", path: "/api/v3/order-requests",
                           status: 401, error_code: "unauthenticated", created_at: Time.current)

      get audits_path

      expect(response.body).to include("/api/v3/order-requests")
      expect(response.body).to include("unauthenticated")

      get audits_path, params: { failures: "1" }

      expect(response.body).to include("/api/v3/order-requests")
      expect(response.body).not_to include("/api/v3/results")
    end
  end
end
