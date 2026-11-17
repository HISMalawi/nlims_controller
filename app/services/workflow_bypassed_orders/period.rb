# frozen_string_literal: true

module WorkflowBypassedOrders
  # The order-date period a listing covers: at most one month (31 days, both dates included).
  # A missing date is filled in so the period is always a month: the current calendar month when neither date is
  # given, otherwise the maximum period counted from (or back from) the date that was given.
  class Period
    MAX_DAYS = 31

    attr_reader :start_date, :end_date, :error

    def initialize(start_value, end_value, today: Time.zone.today)
      start_date, start_error = parse(:start_date, start_value)
      end_date, end_error = parse(:end_date, end_value)
      @error = start_error || end_error
      return if @error

      @start_date, @end_date = fill_in(start_date, end_date, today)
      @error = range_error
    end

    def valid?
      error.nil?
    end

    def days
      (end_date - start_date).to_i + 1
    end

    # The whole of the start and end dates
    def range
      start_date.beginning_of_day..end_date.end_of_day
    end

    def to_h
      { start_date:, end_date:, days: }
    end

    private

    def parse(name, value)
      return [nil, nil] if value.blank?

      [Date.iso8601(value.to_s.strip[/\A\d{4}-\d{2}-\d{2}/].to_s), nil]
    rescue Date::Error
      [nil, "#{name} is not a valid date, use YYYY-MM-DD"]
    end

    def fill_in(start_date, end_date, today)
      return [start_date, end_date] if start_date && end_date
      return [start_date, start_date + (MAX_DAYS - 1)] if start_date
      return [end_date - (MAX_DAYS - 1), end_date] if end_date

      [today.beginning_of_month, today.end_of_month]
    end

    def range_error
      return 'end_date cannot be before start_date' if end_date < start_date
      return unless (end_date - start_date).to_i >= MAX_DAYS

      "the period cannot be longer than one month (#{MAX_DAYS} days)"
    end
  end
end
