# frozen_string_literal: true

# Module API
module API
  # module for V2
  module V2
    # Logs samples that bypassed the order workflow and lists the ones that were logged
    class WorkflowBypassedOrdersController < ApplicationController
      def index
        render_result WorkflowBypassedOrders::ListService.call(params)
      end

      def create
        render_result WorkflowBypassedOrders::LogService.call(params, source_ip: request.remote_ip)
      end

      private

      def render_result(result)
        render json: { error: result.error, message: result.message, data: result.data }, status: result.status
      end
    end
  end
end
