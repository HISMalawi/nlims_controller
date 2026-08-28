# frozen_string_literal: true

module Api
  module V3
    # Unauthenticated: it is how an operator, a client system or a container
    # health check finds out which node it is talking to. Not audited either —
    # a probe every ten seconds is noise, not evidence.
    class HealthController < Api::BaseController
      skip_request_audit
      skip_before_action :authenticate_api_client!
      skip_before_action :enforce_rate_limit!

      def show
        render_data({
                      mode: SislabSync.mode,
                      node_code: SislabSync.node_code,
                      version: SislabSync.version,
                      time: Time.current.iso8601
                    })
      end
    end
  end
end
