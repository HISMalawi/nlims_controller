# frozen_string_literal: true

# Module API
module API
  # module for V2
  module V2
    # OrdersController
    class OrdersController < ApplicationController
      before_action :remote_host, only: %i[create]
      before_action :update_remote_host, only: %i[update]
      before_action :order, only: %i[show update]

      def index
        render json: Order.all.limit(10)
      end

      def show
        render_success('Order Found', OrderSerializer.serialize(@order))
      end

      # rubocop:disable Metrics/AbcSize
      def create
        if (error_message = required_params).present?
          return render_error(error_message, :unprocessable_entity)
        end
        if (specimen = Speciman.find_by(tracking_number: params.dig(:order, :tracking_number)))
          return render_success('order already available', { tracking_number: specimen.tracking_number }, :created)
        end

        status, response = OrderManagement::OrdersService.create_order(params)
        return render_error(response, :unprocessable_entity) unless status

        update_tests(params[:tests]) if params[:tests].present?
        render_success('order created successfully', { tracking_number: response }, :created)
      end
      # rubocop:enable Metrics/AbcSize

      def update
        update_status, message = OrderManagement::OrdersService.update_order(@order, params)
        return render_error(message, :unprocessable_entity) unless update_status

        render_success('order updated successfully', { tracking_number: @order.tracking_number })
      end

      def order_exist
        exist = OrderManagement::OrdersService.order_exist?(params[:tracking_number])
        render json: { data: exist, message: exist ? 'Order Exists' : 'Order Not Available', status: 200 }
      end

      def tracking_numbers
        render json: OrderManagement::OrdersService.order_tracking_numbers_to_logged(
          params.require(:order_id), limit: params[:limit], from: params[:from]
        )
      end

      private

      def remote_host
        return unless params[:tracking_number].present?

        return if TrackingNumberHost.where(tracking_number: params[:tracking_number]).exists?

        TrackingNumberHost.create(
          tracking_number: params[:tracking_number],
          source_host: request.remote_ip,
          source_app_uuid: User.find_by(token: request.headers['token'])&.app_uuid
        )
      end

      def update_remote_host
        return unless params[:tracking_number].present?

        host = TrackingNumberHost.find_by(tracking_number: params[:tracking_number])
        return unless host.present?

        host&.update(
          update_host: request.remote_ip,
          update_app_uuid: User.find_by(token: request.headers['token'])&.app_uuid
        )
      end

      def required_params
        required = {
          %i[order district] => 'district not provided',
          %i[order sending_facility] => 'health facility name not provided',
          %i[order tracking_number] => 'tracking number not provided',
          %i[order requested_by] => 'requesting clinician not provided',
          %i[patient first_name] => 'patient first name not provided',
          %i[patient last_name] => 'patient last name not provided',
          %i[patient gender] => 'patient gender not provided',
          %i[order sample_type name] => 'sample type not provided',
          [:tests] => 'tests not provided',
          %i[order date_created] => 'date for sample drawn not provided',
          %i[order sample_status name] => 'sample status not provided',
          %i[order priority] => 'sample priority level not provided',
          %i[order target_lab] => 'target lab for sample not provided',
          %i[order order_location] => 'sample order location not provided',
          %i[order drawn_by name] => 'first name for person ordering not provided'
        }

        required.each do |path, message|
          value = params.dig(*path.map(&:to_s))
          return message if value.blank?
        end

        nil
      end

      def render_error(message, status)
        render json: { error: true, message: message, data: {} }, status: status
      end

      def render_success(message, data = {}, status = :ok)
        render json: { error: false, message: message, data: data }, status: status
      end

      def update_tests(tests)
        tests.each { |lab_test| OrderService.update_tests(lab_test) }
      end

      def order
        @order = Speciman.find_by(tracking_number: params[:id])
        return render_error('order not available', :not_found) unless @order

        @order
      end
    end
  end
end
