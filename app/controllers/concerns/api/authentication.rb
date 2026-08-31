# frozen_string_literal: true

module Api
  # Every API request carries an API key. There are no sessions, no login
  # endpoint and no short-lived tokens to refresh: the integrations run
  # unattended, and a key that expires overnight is an outage.
  module Authentication
    extend ActiveSupport::Concern

    included do
      before_action :authenticate_api_client!
    end

    private

    def authenticate_api_client!
      key = ApiKey.authenticate(bearer_token)
      return render_api_error(Errors::UNAUTHENTICATED) unless key

      Current.api_key = key
      Current.api_client = key.api_client
      key.touch_last_used!
      true
    end

    def bearer_token
      header = request.headers["Authorization"].to_s
      return nil unless header.start_with?("Bearer ")

      header.delete_prefix("Bearer ").strip.presence
    end

    # Renders and halts on failure, so callers read as a guard:
    #   return unless authorize_scope!("orders:write")
    def authorize_scope!(scope)
      return true if Current.api_key&.allows?(scope)

      render_api_error(Errors::INSUFFICIENT_SCOPE)
      false
    end

    # Guards that always pass, kept so the call sites read as guards.
    #
    # There is nothing here to compare. A key carries the unit of the node that
    # issued it, and the intake writes that unit onto the order rather than the
    # one the payload claims, so a request cannot act for anywhere else. A
    # laboratory cannot be checked here at all: one mLab instance speaks for
    # every laboratory in the unit under a single key, so a code on the key
    # would be right for one bench and wrong for the rest.
    #
    # What keeps one unit out of another's work is that a node only holds the
    # samples it has a hand in — the register and the routing, not a string on
    # a key.
    def authorize_facility!(_facility_code)
      true
    end

    def authorize_lab!(_lab_code)
      true
    end

    # The one boundary that is real: a node speaking for another node. A
    # node-to-node key is pinned to the health facility it belongs to, which on
    # the national node is what stops one unit pushing another's events, or
    # reading the parcels the capital is holding for somebody else.
    def authorize_node!(node_code)
      client = Current.api_client
      return true if client.nil? || client.facility_code.blank?
      return true if client.facility_code == node_code

      render_api_error(Errors::NODE_MISMATCH,
                       message: "esta chave fala pelo nó #{client.facility_code}, não por #{node_code}")
      false
    end
  end
end
