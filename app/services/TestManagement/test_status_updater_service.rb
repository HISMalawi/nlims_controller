# frozen_string_literal: true

# This service updates the status of a test while ensuring valid state transitions.
# It is used in various parts of the application to maintain test status integrity.
module TestManagement
  class TestStatusUpdaterService
    ALLOWED_TRANSITIONS = {
      'drawn' => %w[pending started completed verified rejected test_on_repeat test-rejected voided
                    sample_accepted_at_hub sample_rejected_at_hub sample_intransit_to_ml sample_accepted_at_ml
                    sample_rejected_at_ml],
      'sample_accepted_at_hub' => %w[pending started completed verified rejected test_on_repeat voided
                                     test-rejected sample_intransit_to_ml sample_accepted_at_ml
                                     sample_rejected_at_ml],
      'sample_intransit_to_ml' => %w[pending started completed verified rejected test_on_repeat voided
                                     test-rejected sample_accepted_at_ml sample_rejected_at_ml],
      'sample_accepted_at_ml' => %w[pending started completed verified rejected test_on_repeat voided
                                    test-rejected],
      'pending' => %w[started completed verified rejected test_on_repeat test-rejected voided],
      'started' => %w[completed verified rejected test_on_repeat test-rejected voided],
      'completed' => %w[verified test_on_repeat],
      'verified' => %w[test_on_repeat],
      'test_on_repeat' => %w[completed verified]
    }.freeze

    def initialize(test_id, test_status)
      @test = Test.find_by(id: test_id)
      @new_status = test_status
      @current_status = TestStatus.find_by(id: @test&.test_status_id)
    end

    def update_status
      return false unless valid_input? && valid_transition?

      @test.update!(test_status_id: @new_status.id)
    end

    def self.call(test_id, test_status)
      new(test_id, test_status).update_status
    end

    private

    def valid_input?
      @test.present? && @new_status.present?
    end

    def valid_transition?
      return false if ALLOWED_TRANSITIONS[@current_status&.name].blank?

      ALLOWED_TRANSITIONS[@current_status&.name].include?(@new_status.name) || @current_status == @new_status
    end
  end
end
