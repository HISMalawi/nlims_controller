# frozen_string_literal: true

# source controller for tracking app source
class API::V1::SourceTrackerController < ApplicationController
  def register_order_source
    tracker = TrackingNumberHost.find_or_create_by(
      tracking_number: params[:tracking_number],
      source_host: request.remote_ip,
      source_app_uuid: User.find_by(token: request.headers['token'])&.app_uuid
    )
    render json: tracker, status: :ok
  end
end
