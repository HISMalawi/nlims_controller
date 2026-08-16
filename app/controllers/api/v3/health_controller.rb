# frozen_string_literal: true

module Api
  module V3
    # Unauthenticated: it is how an operator, a client system or a container
    # health check finds out which node it is talking to.
    class HealthController < Api::BaseController
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
