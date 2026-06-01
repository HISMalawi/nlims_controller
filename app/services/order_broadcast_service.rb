# frozen_string_literal: true

# Service for broadcasting order updates via WebSocket
class OrderBroadcastService
  class << self
    # Broadcast status update for an order
    def broadcast_status_update(test_id)
      test = Test.find_by(id: test_id)
      return unless test&.speciman

      order = test.speciman
      payload = build_broadcast_payload(order, 'status_update')

      broadcast_to_channels(order.tracking_number, payload)

      Rails.logger.info("[OrderBroadcastService] Broadcasted status update for tracking_number: #{order.tracking_number}")
    rescue StandardError => e
      Rails.logger.error("[OrderBroadcastService] Failed to broadcast status update: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    end

    # Broadcast result update for an order
    def broadcast_result_update(test_id)
      test = Test.find_by(id: test_id)
      return unless test&.speciman

      order = test.speciman
      payload = build_broadcast_payload(order, 'result_update')

      broadcast_to_channels(order.tracking_number, payload)

      Rails.logger.info("[OrderBroadcastService] Broadcasted result update for tracking_number: #{order.tracking_number}")
    rescue StandardError => e
      Rails.logger.error("[OrderBroadcastService] Failed to broadcast result update: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    end

    # Broadcast order status update (specimen status change)
    def broadcast_order_status_update(order_id)
      order = Speciman.find_by(id: order_id)
      return unless order

      payload = build_broadcast_payload(order, 'order_status_update')

      broadcast_to_channels(order.tracking_number, payload)

      Rails.logger.info("[OrderBroadcastService] Broadcasted order status update for tracking_number: #{order.tracking_number}")
    rescue StandardError => e
      Rails.logger.error("[OrderBroadcastService] Failed to broadcast order status update: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    end

    private

    # Build broadcast payload matching the order payload structure
    def build_broadcast_payload(order, update_type)
      {
        type: update_type,
        timestamp: Time.current.iso8601,
        data: OrderSerializer.serialize(order)
      }
    end

    # Broadcast to both general orders channel and specific tracking number channel
    def broadcast_to_channels(tracking_number, payload)
      # Broadcast to general orders channel
      ActionCable.server.broadcast('orders', payload)

      # Broadcast to specific tracking number channel
      ActionCable.server.broadcast("orders:#{tracking_number}", payload)
    end
  end
end
