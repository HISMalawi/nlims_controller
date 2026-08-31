# frozen_string_literal: true

require "sislab_sync_client"

# Puts the reference client's requests through this node's own Rack stack
# instead of a socket.
#
# SislabSyncClient::Transport is swappable for exactly this reason, and it is
# what lets the suite drive the published client against the real node —
# routing, authentication, scopes, the state machines, the database — without
# booting a server. A client that is only ever tested against a mock of the node
# is a client that agrees with the mock.
#
# It also means every call the client makes goes through the contract check in
# spec/support/openapi_contract.rb, so the walk-through doubles as evidence that
# the client and the document describe the same node.
class RackTransport
  def initialize(session)
    @session = session
  end

  def call(method:, path:, params: {}, body: nil, headers: {})
    @session.public_send(method, path, **options_for(params, body, headers))
    response = @session.response

    [ response.status, response.headers.to_h, response.body ]
  end

  private

  def options_for(params, body, headers)
    return { params: JSON.generate(body), headers: headers.merge("CONTENT_TYPE" => "application/json") } if body
    return { params: params, headers: headers } if params && params.any?

    { headers: headers }
  end
end
