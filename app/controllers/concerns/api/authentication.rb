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

    # A valid key acting on another facility's data is not an authorisation
    # gap to be logged and allowed; it is a refusal.
    def authorize_facility!(facility_code)
      return true if Current.api_client&.acts_for_facility?(facility_code)

      render_api_error(Errors::FACILITY_MISMATCH)
      false
    end

    def authorize_lab!(lab_code)
      return true if Current.api_client&.acts_for_lab?(lab_code)

      render_api_error(Errors::LAB_MISMATCH)
      false
    end
  end
end
