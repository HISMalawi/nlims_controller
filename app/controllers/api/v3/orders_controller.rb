# frozen_string_literal: true

module Api
  module V3
    # Following one sample, by the number written on the tube.
    class OrdersController < Api::BaseController
      def show
        return unless authorize_scope!("orders:read")
        return unless load_order

        render_data(OrderSerializer.call(@order))
      end

      def results
        return unless authorize_scope!("results:read")
        return unless load_order

        render_data(OrderSerializer.call(@order, results: true))
      end

      private

      # Scope first, then existence: a key that may not read orders learns
      # nothing about which tracking numbers this node has issued.
      #
      # A key from another facility is refused rather than answered with an
      # empty result. The sample exists, and pretending otherwise sends an
      # integrator hunting for a fault that is really a permission.
      def load_order
        @order = Order.find_by_tracking_number!(params[:tracking_number])

        authorize_facility!(@order.sending_facility_code)
      end
    end
  end
end
