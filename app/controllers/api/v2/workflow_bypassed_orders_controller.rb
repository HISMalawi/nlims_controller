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

      MAX_PERIOD_DAYS = 31
      # request param => column on workflow_bypassed_orders
      FILTER_COLUMNS = {
        tracking_number: :tracking_number, specimen_type: :specimen_type, test_type: :test_type,
        ordering_facility: :ordering_facility, ordered_by: :ordered_by, lab: :receiving_lab
      }.freeze

      # Lists bypassed orders whose order date falls in the period (at most one month, the current month by default),
      # optionally narrowed by any combination of the filters
      def index
        start_date, end_date, error = resolve_period
        return render_error(error, :unprocessable_content) if error

        orders = filtered_orders(start_date, end_date).to_a
        render_success('bypassed orders retrieved successfully',
                       { period: { start_date:, end_date:, days: (end_date - start_date).to_i + 1 },
                         filters: applied_filters, total: orders.size, orders: orders.map { |o| serialize(o) } })
      end

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

      def resolve_period
        start_date, start_error = date_param(:start_date)
        end_date, end_error = date_param(:end_date)
        error = start_error || end_error
        return [nil, nil, error] if error

        start_date, end_date = default_period(start_date, end_date)
        [start_date, end_date, period_error(start_date, end_date)]
      end

      def date_param(key)
        return [nil, nil] if params[key].blank?

        [Date.iso8601(params[key].to_s.strip[/\A\d{4}-\d{2}-\d{2}/].to_s), nil]
      rescue Date::Error
        [nil, "#{key} is not a valid date, use YYYY-MM-DD"]
      end

      # A missing date is filled in so the period is always a month: the current calendar month when neither
      # date is given, otherwise the maximum period counted from (or back from) the date that was given
      def default_period(start_date, end_date)
        return [start_date, end_date] if start_date && end_date
        return [start_date, start_date + (MAX_PERIOD_DAYS - 1)] if start_date
        return [end_date - (MAX_PERIOD_DAYS - 1), end_date] if end_date

        today = Time.zone.today
        [today.beginning_of_month, today.end_of_month]
      end

      def period_error(start_date, end_date)
        return 'end_date cannot be before start_date' if end_date < start_date
        return unless (end_date - start_date).to_i >= MAX_PERIOD_DAYS

        "the period cannot be longer than one month (#{MAX_PERIOD_DAYS} days)"
      end

      def filtered_orders(start_date, end_date)
        scope = WorkflowBypassedOrder.where(ordered_at: start_date.beginning_of_day..end_date.end_of_day)
        applied_filters.each { |key, value| scope = scope.where(FILTER_COLUMNS[key] => value) }
        scope.order(ordered_at: :desc, id: :desc)
      end

      def applied_filters
        FILTER_COLUMNS.keys.index_with { |key| params[key].to_s.strip }.reject { |_, value| value.blank? }
      end

      def serialize(order)
        {
          tracking_number: order.tracking_number, order_date: order.ordered_at.in_time_zone.iso8601,
          specimen_type: order.specimen_type, test_type: order.test_type,
          ordering_facility: order.ordering_facility, ordered_by: order.ordered_by, lab: order.receiving_lab,
          logged_at: order.created_at.in_time_zone.iso8601
        }
      end

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
