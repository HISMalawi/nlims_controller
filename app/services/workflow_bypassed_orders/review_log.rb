# frozen_string_literal: true

require 'csv'

module WorkflowBypassedOrders
  # Appends bypassed orders that could not be saved (e.g. unknown site code number) to a CSV so they can be
  # reviewed and followed up later. A failure to write the CSV is logged but never raised, because the caller is
  # in the middle of answering an API request.
  module ReviewLog
    HEADERS = %w[logged_at reason tracking_number order_date specimen_type test_type site_code_number facility_name
                 ordered_by lab arv_number source_ip].freeze
    MAX_FIELD_LENGTH = 500
    # Spreadsheets run cells starting with these as formulas, and the values come from API callers
    FORMULA_PREFIX = /\A[=+\-@\t\r]/

    module_function

    def path
      Rails.root.join('log', 'bypassed_orders_for_review.csv')
    end

    def record(details)
      append(HEADERS.map { |header| header == 'logged_at' ? Time.zone.now.iso8601 : safe(details[header.to_sym]) })
      true
    rescue StandardError => e
      Rails.logger.error("Failed to write the bypassed order review CSV: #{e.message}")
      false
    end

    # Exclusive lock so rows from concurrent requests do not interleave; the header goes in first
    def append(row)
      File.open(path, File::WRONLY | File::APPEND | File::CREAT, 0o640) do |file|
        file.flock(File::LOCK_EX)
        file.write(CSV.generate_line(HEADERS)) if file.size.zero? # rubocop:disable Style/ZeroLengthPredicate
        file.write(CSV.generate_line(row))
      end
    end

    def safe(value)
      text = value.to_s.scrub[0, MAX_FIELD_LENGTH]
      text.match?(FORMULA_PREFIX) ? "'#{text}" : text
    end
  end
end
