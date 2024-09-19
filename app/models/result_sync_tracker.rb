# frozen_string_literal: true

# ResultSyncTracker for tracking the status of results syncing to EMR
class ResultSyncTracker < ApplicationRecord
  self.table_name = 'results_sync_trackers'
  after_commit :push_result_to_nlims, on: %i[create update]
  # after_commit :push_result_to_emr, on: %i[create update], if: :local_nlims?

  private

  def local_nlims?
    Config.local_nlims?
  end

  def push_result_to_emr
    return if !Config.master_update_source?(tracking_number) && Config.same_source?(tracking_number)

    SyncWithEmrJob.perform_async({
      tracking_number:,
      status: nil,
      test_id:,
      time: created_at,
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
end
