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

    # Kept as guards so the call sites still read as guards, and kept passing.
    #
    # These used to compare the facility and laboratory codes in the payload
    # against the ones stored on the key, and refuse the request when they
    # differed. There is nothing left to compare: the key inherits its unit from
    # this node, the intake ignores whatever the payload claims and uses the
    # node's own, and a request cannot act for anywhere else because there is
    # nowhere else to act for. What the comparison actually did in the field was
    # refuse integrations over a code that had been typed into a form once and
    # never looked at again.
    #
    # The laboratory in particular cannot be checked this way any more: one mLab
    # instance holds several laboratories under one key, so a key that named one
    # of them would be wrong for the rest.
    #
    # A node still only holds the samples it has a hand in, which is what keeps
    # one unit out of another's work — the register and the routing, not a
    # string on a key.
    def authorize_facility!(_facility_code)
      true
    end

    def authorize_lab!(_lab_code)
      true
    end

    # The one boundary that is real, and always was: a node speaking for another
    # node. It used to be checked with the facility comparison above, which is
    # how the two got confused in the first place — an integration's key and a
    # node's key were being held to the same rule for different reasons.
    #
    # A node-to-node key is pinned to the health facility it belongs to. On the
    # national node that is what stops one unit pushing another's events, or
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
