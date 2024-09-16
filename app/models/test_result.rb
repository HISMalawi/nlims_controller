# frozen_string_literal: true

require 'sync_util_service'
require 'emr_sync_service'
require 'local_nlims_sync_service'

# TestResult Model
class TestResult < ApplicationRecord
  after_commit :enqueue_create_test_result_acknowledgement, on: %i[create update], if: :local_nlims?
  # after_commit :enqueue_push_result_to_emr, on: %i[create update], if: :local_nlims?
  # after_commit :enqueue_push_result_to_master_nlims, on: %i[create update], if: :local_nlims?
  # after_commit :enqueue_push_result_to_local_nlims, on: %i[create update], unless: :local_nlims?

  def create_test_result_acknowledgement
    Rails.logger.debug "Executing create_test_result_acknowledgement with tracking_number: #{tracking_number}"
    sync_util_service = SyncUtilService.new
    sync_util_service.ack_result_at_facility_level(
      tracking_number,
      test_id,
      time_entered,
      3,
      'local_nlims_at_facility'
    )
  end

  def push_result_to_local_nlims
    Rails.logger.debug "Executing push_result_to_local_nlims with tracking_number: #{tracking_number}"
    ResultSyncTracker.create(tracking_number:, test_id:, app: 'nlims')
    local_nlims = LocalNlimsSyncService.new(tracking_number)
    local_nlims.push_test_actions_to_nlims(test_id:, action: 'result_update')
  end

  def push_result_to_master_nlims
    Rails.logger.debug "Executing push_result_to_master_nlims with tracking_number: #{tracking_number}"
    return if Config.master_update_source?(tracking_number)

    ResultSyncTracker.create(tracking_number:, test_id:, app: 'nlims')
    local_nlims = LocalNlimsSyncService.new(nil)
    local_nlims.push_test_actions_to_nlims(test_id:, action: 'result_update')
  end

  def push_result_to_emr
    Rails.logger.debug "Executing push_result_to_emr with tracking_number: #{tracking_number}"
    return if Config.same_source?(tracking_number)

    ResultSyncTracker.create(tracking_number:, test_id:, app: 'emr')
    emr_service = EmrSyncService.new
    # emr_service = emr_service.emr_instance_for_sync(emr_service, tracking_number)
    response = emr_service.push_result_to_emr(tracking_number)
    return unless response

    emr_service.push_status_to_emr(tracking_number, 'verified', created_at)
    create_emr_test_result_acknowledgement
    ResultSyncTracker.find_by(tracking_number:, test_id:,
                              app: 'emr')&.update(sync_status: true)
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

  private

  def enqueue_create_test_result_acknowledgement
    TestResultJob.perform_async(id, 'create_test_result_acknowledgement')
  end

  def enqueue_push_result_to_emr
    TestResultJob.perform_async(id, 'push_result_to_emr')
  end

  def enqueue_push_result_to_master_nlims
    TestResultJob.perform_async(id, 'push_result_to_master_nlims')
  end

  def enqueue_push_result_to_local_nlims
    TestResultJob.perform_async(id, 'push_result_to_local_nlims')
  end

  def local_nlims?
    Config.local_nlims?
  end
end
