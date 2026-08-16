# frozen_string_literal: true

module Api
  # Base for every JSON endpoint. API clients are other systems, not browsers,
  # so this deliberately does not inherit the browser-facing ApplicationController.
  #
  # S2 adds API key authentication, scope checks and the shared error envelope
  # here; for now it only fixes the response shape.
  class BaseController < ActionController::API
    private

    def render_data(data, meta: {}, status: :ok)
      render json: { data: data, meta: meta, errors: [] }, status: status
    end

    def render_error(code, message, field: nil, status: :unprocessable_entity)
      error = { code: code, message: message }
      error[:field] = field if field
      render json: { data: nil, meta: {}, errors: [ error ] }, status: status
    end
  end
end
