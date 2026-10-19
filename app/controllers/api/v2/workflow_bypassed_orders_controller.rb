# frozen_string_literal: true

# Module API
module API
  # module for V2
  module V2
    # Logs samples that bypassed the order workflow
    class WorkflowBypassedOrdersController < ApplicationController
      REQUIRED_PARAMS = {
        tracking_number: 'tracking number not provided',
        order_date: 'order date not provided',
        specimen_type: 'specimen type not provided',
        test_type: 'test type not provided',
        ordering_facility: 'facility the order originated from not provided',
        ordered_by: 'person who placed the order not provided',
        lab: 'lab that received the order not provided'
      }.freeze

      # rubocop:disable Metrics/AbcSize
      def create
        if (error_message = validate_params).present?
          return render_error(error_message, :unprocessable_content)
        end

        # An order in specimen went through the workflow, so it did not bypass it
        if Speciman.exists?(tracking_number:)
          return render_success('order exists in nlims, did not bypass the workflow, skipped',
                                { tracking_number: }, :ok)
        end
        return render_already_logged if WorkflowBypassedOrder.exists?(tracking_number:)

        record = WorkflowBypassedOrder.new(record_attributes.merge(tracking_number:))
        return render_error(record.errors.full_messages.join(', '), :unprocessable_content) unless record.save

        render_success('bypassed order logged successfully', { tracking_number: }, :created)
      rescue ActiveRecord::RecordNotUnique
        # lost a race with a concurrent request for the same tracking number
        render_already_logged
      end
      # rubocop:enable Metrics/AbcSize

      private

      def tracking_number
        params[:tracking_number].to_s.strip
      end

      def render_already_logged
        render_success('bypassed order already logged, skipped', { tracking_number: }, :ok)
      end

      def validate_params
        REQUIRED_PARAMS.each do |key, message|
          return message if params[key].blank?
        end
        return 'order date is not a valid datetime' if ordered_at.nil?

        nil
      end

      def ordered_at
        @ordered_at ||= Time.zone.parse(params[:order_date].to_s)
      rescue ArgumentError
        nil
      end

      def record_attributes
        {
          ordered_at:,
          specimen_type: params[:specimen_type].to_s.strip,
          test_type: params[:test_type].to_s.strip,
          ordering_facility: params[:ordering_facility].to_s.strip,
          ordered_by: params[:ordered_by].to_s.strip,
          receiving_lab: params[:lab].to_s.strip
        }
      end

      def render_error(message, status)
        render json: { error: true, message: message, data: {} }, status: status
      end

      def render_success(message, data = {}, status = :ok)
        render json: { error: false, message: message, data: data }, status: status
      end
    end
  end
end
