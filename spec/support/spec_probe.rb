# frozen_string_literal: true

# Scope checks, facility checks, idempotency and rate limiting are properties of
# every endpoint, but the first real endpoints that use them only arrive in S7.
# This probe exercises them now, through the same BaseController every endpoint
# inherits, without putting test-only routes in the application.
class SpecProbeController < Api::BaseController
  def show
    return unless authorize_scope!("orders:read")

    render_data({ ok: true })
  end

  def create
    return unless authorize_scope!("orders:write")

    idempotent do
      render_data({ id: SecureRandom.uuid }, status: :created)
    end
  end

  def facility
    return unless authorize_facility!(params[:facility_code])

    render_data({ ok: true })
  end

  def lab
    return unless authorize_lab!(params[:lab_code])

    render_data({ ok: true })
  end

  def boom
    raise ActiveRecord::RecordNotFound
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    # `append` adds to whatever config/routes.rb draws rather than replacing it,
    # so the real endpoints stay routable alongside the probe.
    Rails.application.routes.append do
      scope "spec_probe", controller: "spec_probe" do
        get "/", action: :show
        post "/", action: :create
        get "/facility/:facility_code", action: :facility
        get "/lab/:lab_code", action: :lab
        get "/boom", action: :boom
      end
    end

    Rails.application.reload_routes!
  end
end
