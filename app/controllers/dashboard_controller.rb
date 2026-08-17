# frozen_string_literal: true

# The first screen. It answers one question — is this node talking to the rest
# of the country, and if not, how far behind is it — and then gets out of the
# way towards the orders screen.
class DashboardController < ApplicationController
  RECENT_ORDERS = 8

  def show
    @status = NodeStatus.call

    @recent_orders = Order.includes(:patient)
                          .order(created_at: :desc, id: :desc)
                          .limit(RECENT_ORDERS)
                          .to_a
  end
end
