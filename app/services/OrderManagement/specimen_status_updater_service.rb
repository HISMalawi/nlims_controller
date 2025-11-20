# frozen_string_literal: true

# This service updates the status of a specimen while ensuring valid state transitions.
# It is used in various parts of the application to maintain specimen status integrity.
module OrderManagement
  class SpecimenStatusUpdaterService
    ALLOWED_TRANSITIONS = {
      'specimen_not_collected' => %w[specimen_collected specimen_rejected specimen_accepted sample_accepted_at_hub
                                     sample_rejected_at_hub sample_accepted_at_ml sample_rejected_at_ml],
      'specimen_collected' => %w[specimen_accepted specimen_rejected sample_accepted_at_hub sample_rejected_at_hub
                                 sample_accepted_at_ml sample_rejected_at_ml],
      'sample_accepted_at_hub' => %w[specimen_accepted specimen_rejected sample_accepted_at_ml sample_rejected_at_ml],
      'sample_accepted_at_ml' => %w[specimen_accepted specimen_rejected]
    }.freeze

    def initialize(order, specimen_status)
      @order = order
      @specimen_status = specimen_status
      @current_status = SpecimenStatus.find_by(id: @order&.specimen_status_id)
    end

    def update_status
      return false unless valid_input? && valid_transition?

      @order.update!(specimen_status_id: @specimen_status.id)
    end

    def self.call(order, specimen_status)
      new(order, specimen_status).update_status
    end

    private

    def valid_input?
      @order.present? && @specimen_status.present?
    end

    def valid_transition?
      return false if ALLOWED_TRANSITIONS[@current_status&.name].blank?

      ALLOWED_TRANSITIONS[@current_status&.name].include?(@specimen_status.name) || @current_status == @specimen_status
    end
  end
end
