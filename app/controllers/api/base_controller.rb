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

    rescue_from InvalidRequest do |exception|
      render_api_error(Errors::UNPROCESSABLE, message: exception.message, field: exception.field)
    end

    rescue_from ActiveRecord::RecordInvalid do |exception|
      render_api_error(
        Errors::UNPROCESSABLE,
        message: exception.record.errors.full_messages.to_sentence,
        field: exception.record.errors.attribute_names.first
      )
    end

    private

    # The request body with every clinical term in object form.
    #
    # A term may be named with an object or with a bare string, and strong
    # parameters cannot declare a key as both. Normalising here means each
    # controller declares one shape and both arrive in it.
    def payload
      @payload ||= Dictionary::Reference.expand(params)
    end

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
