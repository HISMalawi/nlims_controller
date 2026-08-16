# frozen_string_literal: true

module Api
  # Base for every JSON endpoint. API clients are other systems, not browsers,
  # so this deliberately does not inherit the browser-facing ApplicationController.
  #
  # Include order is the callback order: auditing wraps everything so a request
  # rejected by authentication is still recorded, and the rate limiter runs after
  # authentication because the bucket is per key.
  class BaseController < ActionController::API
    include Api::Errors
    include Api::Auditing
    include Api::Authentication
    include Api::RateLimiting
    include Api::Idempotency

    rescue_from ActiveRecord::RecordNotFound do
      render_api_error(Errors::NOT_FOUND)
    end

    rescue_from ActiveRecord::RecordInvalid do |exception|
      render_api_error(
        Errors::UNPROCESSABLE,
        message: exception.record.errors.full_messages.to_sentence,
        field: exception.record.errors.attribute_names.first
      )
    end

    private

    def render_data(data, meta: {}, status: :ok)
      render json: { data: data, meta: meta, errors: [] }, status: status
    end

    def render_api_error(code, message: nil, field: nil, status: nil)
      error = { code: code, message: message || Errors.message_for(code) }
      error[:field] = field if field

      render json: { data: nil, meta: {}, errors: [ error ] },
             status: status || Errors.status_for(code)
    end
  end
end
