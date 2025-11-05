# frozen_string_literal: true

# ResultSyncTracker for tracking the status of results syncing to EMR
class ResultSyncTracker < ApplicationRecord
  self.table_name = 'results_sync_trackers'
  after_commit :push_result_to_nlims, on: %i[create]
  after_commit :create_test_result_acknowledgement, on: %i[create], if: :local_nlims?
  after_commit :push_result_to_emr, on: %i[create], if: :local_nlims?

  private

  def local_nlims?
    Config.local_nlims?
  end

  def push_result_to_emr
    return if !Config.master_update_source?(tracking_number) && Config.same_source?(tracking_number)
    return if Speciman.find_by(tracking_number:)&.source_system&.downcase == 'iblis'

    SyncWithEmrJob.perform_async({
      tracking_number:,
      status: nil,
      test_id:,
      action: 'result_update'
    }.stringify_keys)
  end

  def push_result_to_nlims
    return unless app == 'nlims'

    Rails.logger.debug "Executing push_result_to_nlims with tracking_number: #{tracking_number}"
    SyncWithNlimsJob.perform_async({
      identifier: test_id,
      type: 'test',
      action: 'result_update'
    }.stringify_keys)
  end

  def create_test_result_acknowledgement
    Rails.logger.debug "Executing create_test_result_acknowledgement with tracking_number: #{tracking_number}"
    SyncUtilService.ack_result_at_facility_level(
      tracking_number,
      test_id,
      created_at,
      3,
      'local_nlims_at_facility'
    )
  end
end
