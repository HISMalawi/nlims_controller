# frozen_string_literal: true

module WorkflowBypassedOrders
  # Logs a sample that bypassed the order workflow. Nothing is logged when NLIMS already has an order for the
  # tracking number (the sample did not bypass anything), when it was logged before, or when the facility's site
  # code number matches no enabled site (the details sent are then written to the review log).
  class LogService
    REQUIRED_PARAMS = {
      tracking_number: 'tracking number not provided',
      order_date: 'order date not provided',
      specimen_type: 'specimen type not provided',
      test_type: 'test type not provided',
      site_code_number: 'facility site code number not provided',
      ordered_by: 'person who placed the order not provided',
      lab: 'lab that received the order not provided'
    }.freeze
    ORDER_EXISTS_MESSAGE = 'order exists in nlims, did not bypass the workflow, skipped'
    UNMATCHED_SITE_MESSAGE = 'site code number does not match any site in nlims'

    def self.call(params, source_ip: nil)
      new(params, source_ip).call
    end

    def initialize(params, source_ip)
      @params = params
      @source_ip = source_ip
    end

    def call
      error = validation_error
      return Result.failure(error) if error
      return skipped(ORDER_EXISTS_MESSAGE) if Speciman.exists?(tracking_number:)
      return already_logged if WorkflowBypassedOrder.exists?(tracking_number:)

      facility = SiteLookup.facility_name(site_code_number)
      return unmatched_site if facility.nil?

      save(facility)
    rescue ActiveRecord::RecordNotUnique
      # lost a race with a concurrent request for the same tracking number
      already_logged
    end

    private

    def save(facility)
      record = WorkflowBypassedOrder.new(attributes(facility))
      return Result.failure(record.errors.full_messages.join(', ')) unless record.save

      Result.success('bypassed order logged successfully', { tracking_number: }, :created)
    end

    def skipped(message)
      Result.success(message, { tracking_number: })
    end

    def already_logged
      skipped('bypassed order already logged, skipped')
    end

    def unmatched_site
      ReviewLog.record(review_details)
      Result.failure(UNMATCHED_SITE_MESSAGE)
    end

    def validation_error
      REQUIRED_PARAMS.each do |key, message|
        return message if value_for(key).blank?
      end
      'order date is not a valid datetime' if ordered_at.nil?
    end

    def value_for(key)
      key == :site_code_number ? site_code_number : @params[key]
    end

    def tracking_number
      @params[:tracking_number].to_s.strip
    end

    # The facility is sent as an object, { site_code_number:, name: }. Only the site code number is used: the
    # name saved is the name NLIMS holds for that site. Anything else (e.g. a plain string) has no code.
    def facility_params
      facility = @params[:ordering_facility]
      facility.respond_to?(:key?) ? facility : {}
    end

    def site_code_number
      facility_params[:site_code_number].to_s.strip
    end

    def ordered_at
      @ordered_at ||= Time.zone.parse(@params[:order_date].to_s)
    rescue ArgumentError
      nil
    end

    def text(key)
      @params[key].to_s.strip
    end

    def attributes(facility)
      {
        tracking_number:, ordered_at:, ordering_facility: facility, arv_number: text(:arv_number).presence,
        specimen_type: text(:specimen_type), test_type: text(:test_type), ordered_by: text(:ordered_by),
        receiving_lab: text(:lab)
      }
    end

    def review_details
      {
        reason: UNMATCHED_SITE_MESSAGE, tracking_number:, order_date: @params[:order_date],
        specimen_type: @params[:specimen_type], test_type: @params[:test_type], site_code_number:,
        facility_name: facility_params[:name], ordered_by: @params[:ordered_by], lab: @params[:lab],
        arv_number: @params[:arv_number], source_ip: @source_ip
      }
    end
  end
end
