# frozen_string_literal: true

require 'sync_util_service'
require 'emr_sync_service'

# TestResult Model
class TestResult < ApplicationRecord
  after_create :create_test_result_acknowledgement
  after_create :push_result_to_emr

  def create_test_result_acknowledgement
    sync_util_service = SyncUtilService.new
    sync_util_service.ack_result_at_facility_level(
      tracking_number,
      test_id,
      time_entered,
      3,
      'local_nlims_at_facility'
    )
  end

  def push_result_to_emr
    emr_service = EmrSyncService.new
    response = emr_service.push_result_to_emr(tracking_number)
    return unless response

    emr_service.push_status_to_emr(tracking_number, 'verified', created_at)
    create_emr_test_result_acknowledgement
  end

  def tracking_number
    Speciman.find(Test.find(test_id).specimen_id).tracking_number
  end

  def create_emr_test_result_acknowledgement
    sync_util_service = SyncUtilService.new
    sync_util_service.ack_result_at_facility_level(
      tracking_number,
      test_id,
      time_entered,
      2,
      'emr_at_facility'
    )
  end
end
