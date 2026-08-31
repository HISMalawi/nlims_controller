# frozen_string_literal: true

module Api
  # One row per request, written whatever the outcome. A rejected request is the
  # one most worth having: it is how a key being probed, or an integration
  # pointed at the wrong node, becomes visible.
  module Auditing
    extend ActiveSupport::Concern

    included do
      class_attribute :audit_requests, instance_writer: false, default: true
    end

    class_methods do
      # For an endpoint whose traffic is noise rather than evidence — the health
      # probe a load balancer runs every few seconds.
      def skip_request_audit
        self.audit_requests = false
      end
    end

    # Wraps everything the controller does, the rescue_from handlers included.
    #
    # This was an around_action, and its ensure fired while an exception was
    # still on its way up — before ActionController::Rescue had turned it into
    # the 404 or 422 the client actually received. `response.status` is still
    # the untouched 200 at that moment, so every refusal raised from a model was
    # written down as a success with no error code. The trail then said an
    # integration was working while it saved nothing, which is the one thing an
    # audit trail must never say. Overriding process_action puts this outside
    # Rescue instead of inside it.
    def process_action(*)
      @audit_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      Current.request_id = request.request_id
      Current.ip = request.remote_ip

      super
    rescue StandardError
      # Nothing handled it, so nothing set a status. The middleware will answer
      # 500 and the trail should say 500 rather than the default it can see.
      @audit_status = 500
      raise
    ensure
      write_audit
    end

    private

    def write_audit
      return unless self.class.audit_requests

      status = @audit_status || response.status

      RequestAudit.create!(
        api_client: Current.api_client,
        api_key: Current.api_key,
        request_method: request.request_method,
        path: request.path,
        status: status,
        duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - @audit_started_at) * 1000).round,
        ip: request.remote_ip,
        request_id: request.request_id,
        error_code: rendered_error_code(status),
        created_at: Time.current
      )
    rescue StandardError => e
      # An audit failure must not turn a good request into a 500. It is loud in
      # the log instead.
      Rails.logger.error("[audit] could not record request: #{e.class}: #{e.message}")
    end

    def rendered_error_code(status)
      return nil if status < 400

      body = response.body.presence
      return nil unless body&.start_with?("{")

      JSON.parse(body).dig("errors", 0, "code")
    rescue JSON::ParserError
      nil
    end
  end
end
