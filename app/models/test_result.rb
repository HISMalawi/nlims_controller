# frozen_string_literal: true

# TestResult Model
class TestResult < ApplicationRecord
  after_commit :create_test_result_acknowledgement, on: %i[create update], if: :local_nlims?

  private

  def local_nlims?
    Config.local_nlims?
  end

  def create_test_result_acknowledgement
    Rails.logger.debug "Executing create_test_result_acknowledgement with tracking_number: #{tracking_number}"
    SyncUtilService.ack_result_at_facility_level(
      tracking_number,
      test_id,
      time_entered,
      3,
      'local_nlims_at_facility'
    )
  end

  def tracking_number
    Speciman.find(Test.find(test_id).specimen_id)&.tracking_number
  end
end
