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

  # The trail is read to answer "is this integration working?", so a refusal
  # recorded as a success is worse than no row at all. These two used to be
  # written down as 200 with no error code: the audit ran inside the rescue
  # handlers rather than outside them, and read the status before anything had
  # set one. An EMR whose every order was refused looked, on this screen, like
  # an EMR that was working.
  it "records a refusal raised from a model, not the status nobody set" do
    _key, token = issue_key(scopes: %w[orders:read])

    get "/spec_probe/boom", headers: auth_headers(token)

    expect(response).to have_http_status(:not_found)

    audit = RequestAudit.last
    expect(audit.path).to eq("/spec_probe/boom")
    expect(audit.status).to eq(404)
    expect(audit.error_code).to eq("not_found")
  end

  it "records an invalid record as the 422 the client received" do
    _key, token = issue_key(scopes: %w[results:write])
    order = create(:order)

    patch "/spec_probe/orders/#{order.tracking_number}",
          params: { status: "completed" }, headers: auth_headers(token)

    expect(response).to have_http_status(:unprocessable_content)

    audit = RequestAudit.last
    expect(audit.status).to eq(422)
    expect(audit.error_code).to eq("unprocessable")
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
