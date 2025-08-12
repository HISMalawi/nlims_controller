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

  def update_order_source_couch_id
    order = Speciman.find_by(tracking_number: params[:tracking_number], sending_facility: params[:sending_facility])
    if order.nil?
      render json: { error: 'Order not found' }, status: :not_found
      return
    end
    order&.update(couch_id: params[:couch_id])
    render json: { message: 'Update successful' }, status: :ok
  end
end
