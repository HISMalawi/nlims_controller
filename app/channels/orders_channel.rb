# frozen_string_literal: true

# Channel for broadcasting order updates (status and results)
class OrdersChannel < ApplicationCable::Channel
  def subscribed
    # Subscribe to all orders
    stream_from 'orders'

    # Or subscribe to specific tracking number if provided
    return unless params[:tracking_number].present?

    stream_from "orders:#{params[:tracking_number]}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
