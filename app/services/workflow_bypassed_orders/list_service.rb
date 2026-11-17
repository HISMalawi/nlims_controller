# frozen_string_literal: true

module WorkflowBypassedOrders
  # Lists the logged bypassed orders whose order date falls in a period (the current month unless dates are given),
  # optionally narrowed by any combination of filters. The period used is part of the answer.
  class ListService
    # request param => column on workflow_bypassed_orders
    FILTER_COLUMNS = {
      tracking_number: :tracking_number, specimen_type: :specimen_type, test_type: :test_type,
      ordering_facility: :ordering_facility, ordered_by: :ordered_by, lab: :receiving_lab, arv_number: :arv_number
    }.freeze

    def self.call(params)
      new(params).call
    end

    def initialize(params)
      @params = params
    end

    def call
      period = Period.new(@params[:start_date], @params[:end_date])
      return Result.failure(period.error) unless period.valid?

      orders = filtered_orders(period).to_a
      Result.success('bypassed orders retrieved successfully',
                     { period: period.to_h, filters: applied_filters, total: orders.size,
                       orders: orders.map { |order| serialize(order) } })
    end

    private

    def filtered_orders(period)
      scope = WorkflowBypassedOrder.where(ordered_at: period.range)
      applied_filters.each { |key, value| scope = scope.where(FILTER_COLUMNS[key] => value) }
      scope.order(ordered_at: :desc, id: :desc)
    end

    def applied_filters
      @applied_filters ||= FILTER_COLUMNS.keys.index_with { |key| @params[key].to_s.strip }.reject { |_, v| v.blank? }
    end

    def serialize(order)
      {
        tracking_number: order.tracking_number, order_date: order.ordered_at.in_time_zone.iso8601,
        specimen_type: order.specimen_type, test_type: order.test_type,
        ordering_facility: order.ordering_facility, ordered_by: order.ordered_by, lab: order.receiving_lab,
        arv_number: order.arv_number, logged_at: order.created_at.in_time_zone.iso8601
      }
    end
  end
end
