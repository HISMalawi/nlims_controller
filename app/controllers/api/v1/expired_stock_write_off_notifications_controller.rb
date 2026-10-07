# frozen_string_literal: true

class API::V1::ExpiredStockWriteOffNotificationsController < ApplicationController
  def create
    recipients = Array(params[:recipients]).filter_map { |email| email.presence }
    stock_transactions = Array(params[:stock_transactions]).map do |transaction|
      transaction.permit(
        :stock_id,
        :lot,
        :batch,
        :expiry_date,
        :remaining_balance
      ).to_h
    end

    return render json: { error: 'Recipients are required' }, status: :unprocessable_entity if recipients.empty?
    return render json: { error: 'Stock transactions are required' }, status: :unprocessable_entity if stock_transactions.empty?

    ExpiredStockWriteOffMailer.notification(recipients, stock_transactions).deliver_now

    render json: { message: 'Expired stock write-off notification sent' }, status: :ok
  end
end