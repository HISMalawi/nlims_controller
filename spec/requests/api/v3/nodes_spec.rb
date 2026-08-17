# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /api/v3/nodes/heartbeat", mode: :national, type: :request do
  let(:api_client) { create(:api_client, :node) }
  let(:token) { issue_key(api_client: api_client, scopes: %w[sync:push]).last }

  def beat(body = {}, bearer: token)
    post "/api/v3/nodes/heartbeat",
         params: { node_code: "HCM", version: "2.0.0", dictionary_cursor: 1284,
                   outbox_pending: 3, outbox_failing: 1, last_error: "timeout" }.merge(body).to_json,
         headers: { "Authorization" => "Bearer #{bearer}", "Content-Type" => "application/json" }
  end

  it "records the node and what it is worried about" do
    beat

    expect(response).to have_http_status(:ok)

    node = Node.find_by!(node_code: "HCM")
    expect(node.version).to eq("2.0.0")
    expect(node.dictionary_cursor).to eq(1284)
    expect(node.outbox_pending).to eq(3)
    expect(node.outbox_failing).to eq(1)
    expect(node.last_error).to eq("timeout")
    expect(node.last_seen_at).to be_present
  end

  it "updates the node it already knows rather than adding another" do
    beat
    expect { beat({ outbox_pending: 0 }) }.not_to change(Node, :count)

    expect(Node.sole.outbox_pending).to be_zero
  end

  # So an operator standing at the laboratory can see the node is behind
  # without having to telephone the capital.
  it "answers with how far the national dictionary has moved" do
    create(:test_type)

    beat

    expect(response.parsed_body.dig("data", "dictionary_cursor")).to eq(Dictionary.cursor)
  end

  # Silence from a laboratory otherwise looks exactly like a laboratory with
  # nothing to send, and telling those apart is the whole point.
  it "makes a node that stops reporting visible" do
    beat
    node = Node.sole

    expect(node).not_to be_stale
    expect(Node.stale).to be_empty

    node.update!(last_seen_at: 2.hours.ago)

    expect(node.reload).to be_stale
    expect(Node.stale).to include(node)
  end

  it "answers 403 for a node reporting under another node's code" do
    pinned = create(:api_client, kind: "node", facility_code: "XAI")

    beat({}, bearer: issue_key(api_client: pinned, scopes: %w[sync:push]).last)

    expect(response).to have_http_status(:forbidden)
  end

  it "answers 401 without a key" do
    post "/api/v3/nodes/heartbeat",
         params: { node_code: "HCM" }.to_json,
         headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
  end
end
