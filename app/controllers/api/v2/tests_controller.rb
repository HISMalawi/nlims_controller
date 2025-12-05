# frozen_string_literal: true

# Module API
module API
  # module for V2
  module V2
    # TestsController
    class TestsController < ApplicationController
      before_action :update_remote_host, only: [:update_test]
      before_action :order, only: %i[show update acknowledge_test_results_receipt]

      def update
        status, response = TestManagement::TestsService.update_tests(@order, params)
        if status == true
          render_success(response, OrderSerializer.serialize(@order))
        else
          render_error(response, :unprocessable_entity)
        end
      end

      def acknowledge_test_results_receipt
        status, response = TestManagement::TestsService.acknowledge_test_results_receipt(@order, params)
        if status == true
          render_success(response)
        else
          render_error(response, :unprocessable_entity)
        end
      end

      private

      def update_remote_host
        return unless params[:id].present?

        host = if Config.local_nlims?
                 TrackingNumberHost.find_or_create_by(
                   tracking_number: params[:id],
                   source_host: request.remote_ip
                 )
               else
                 TrackingNumberHost.find_by(
                   tracking_number: params[:id],
                   source_host: request.remote_ip
                 )
               end

        return unless host.present?

        host&.update(
          update_host: request.remote_ip,
          update_app_uuid: User.find_by(token: request.headers['token'])&.app_uuid
        )
      end

      def render_error(message, status)
        render json: { error: true, message: message, data: {} }, status: status
      end

      def render_success(message, data = {}, status = :ok)
        render json: { error: false, message: message, data: data }, status: status
      end

      def order
        @order = if params[:couch_id].present?
                   Speciman.find_by(tracking_number: params[:id], couch_id: params[:couch_id])
                 else
                   Speciman.find_by(tracking_number: params[:id])
                 end
        return render_error('order not available', :not_found) unless @order

        @order
      end
    end
  end
end
