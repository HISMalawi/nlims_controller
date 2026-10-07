# frozen_string_literal: true

class API::V1::ExpiredStockWriteOffNotificationsController < ApplicationController
  def create
    facility_user = User.find_by(token: request.headers['token'])

    return render json: { error: 'Invalid facility token' }, status: :unauthorized unless facility_user

    unless facility_user.mlab_callback_enabled? &&
         facility_user.mlab_callback_base_url.present? &&
         facility_user.mlab_callback_token.present?
      return render json: { error: 'Facility callback is not configured' },
                    status: :unprocessable_entity
    end

    recipients = Array(params[:recipients]).filter_map { |email| email.presence }
    mail_log_id = params[:mail_log_id].presence
    stock_transactions = Array(params[:stock_transactions]).map do |transaction|
      transaction.permit(
        :stock_id,
        :stock_item_name,
        :lot,
        :batch,
        :expiry_date,
        :remaining_balance
      ).to_h
    end

    return render json: { error: 'Recipients are required' }, status: :unprocessable_entity if recipients.empty?
    return render json: { error: 'Mail log ID is required' }, status: :unprocessable_entity if mail_log_id.blank?
    return render json: { error: 'Stock transactions are required' }, status: :unprocessable_entity if stock_transactions.empty?

    ExpiredStockWriteOffNotificationJob.perform_later(
      recipients,
      stock_transactions,
      mail_log_id,
      facility_user.mlab_callback_base_url,
      facility_user.mlab_callback_token
    )

    render json: {
      message: 'Expired stock write-off notification queued',
      mail_log_id: mail_log_id
    }, status: :accepted
  end
end