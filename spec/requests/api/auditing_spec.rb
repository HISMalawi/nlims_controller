# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Request auditing", type: :request do
  it "records an accepted request against its client and key" do
    key, token = issue_key(scopes: %w[orders:read])

    expect { get "/spec_probe", headers: auth_headers(token) }
      .to change(RequestAudit, :count).by(1)

    audit = RequestAudit.last
    expect(audit.api_client).to eq(key.api_client)
    expect(audit.api_key).to eq(key)
    expect(audit.request_method).to eq("GET")
    expect(audit.path).to eq("/spec_probe")
    expect(audit.status).to eq(200)
    expect(audit.ip).to be_present
    expect(audit.duration_ms).to be >= 0
    expect(audit.error_code).to be_nil
  end

  # The rejected ones are the rows worth having: a key being probed, or an
  # integration pointed at the wrong node, only shows up here.
  it "records a rejected request even though there is no client to attribute it to" do
    expect { get "/spec_probe" }.to change(RequestAudit, :count).by(1)

    audit = RequestAudit.last
    expect(audit.api_client).to be_nil
    expect(audit.status).to eq(401)
    expect(audit.error_code).to eq("unauthenticated")
  end

  it "records the error code of a refused scope" do
    _key, token = issue_key(scopes: %w[dictionary:read])

    get "/spec_probe", headers: auth_headers(token)

    expect(RequestAudit.last.error_code).to eq("insufficient_scope")
  end

  it "does not audit the health endpoint" do
    expect { get "/api/v3/health" }.not_to change(RequestAudit, :count)
  end

  it "never turns an audit failure into a failed request" do
    _key, token = issue_key(scopes: %w[orders:read])
    allow(RequestAudit).to receive(:create!).and_raise(ActiveRecord::StatementInvalid, "table is gone")

    get "/spec_probe", headers: auth_headers(token)

    expect(response).to have_http_status(:ok)
  end
end
