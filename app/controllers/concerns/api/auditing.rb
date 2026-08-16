# frozen_string_literal: true

module Api
  # One row per request, written whatever the outcome. A rejected request is the
  # one most worth having: it is how a key being probed, or an integration
  # pointed at the wrong node, becomes visible.
  module Auditing
    extend ActiveSupport::Concern

    included do
      around_action :audit_request
    end

    private

    def audit_request
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      Current.request_id = request.request_id
      Current.ip = request.remote_ip

      yield
    ensure
      write_audit(started)
    end

    def write_audit(started)
      RequestAudit.create!(
        api_client: Current.api_client,
        api_key: Current.api_key,
        request_method: request.request_method,
        path: request.path,
        status: response.status,
        duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round,
        ip: request.remote_ip,
        request_id: request.request_id,
        error_code: rendered_error_code,
        created_at: Time.current
      )
    rescue StandardError => e
      # An audit failure must not turn a good request into a 500. It is loud in
      # the log instead.
      Rails.logger.error("[audit] could not record request: #{e.class}: #{e.message}")
    end

    def rendered_error_code
      return nil if response.successful?

      body = response.body.presence
      return nil unless body&.start_with?("{")

      JSON.parse(body).dig("errors", 0, "code")
    rescue JSON::ParserError
      nil
    end
  end
end
