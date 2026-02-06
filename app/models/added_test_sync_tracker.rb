# frozen_string_literal: true

# AddedTestSyncTracker for tracking tests added to orders that need syncing
class AddedTestSyncTracker < ApplicationRecord
  self.table_name = 'added_test_sync_trackers'
  after_commit :push_added_test_to_nlims, on: %i[create]

  private

  def push_added_test_to_nlims
    return unless app == 'nlims'

    Rails.logger.debug "Executing push_added_test_to_nlims with tracking_number: #{tracking_number}, test_id: #{test_id}"
    return unless Config.local_nlims?

    SyncWithNlimsJob.perform_async({
      identifier: test_id,
      type: 'test',
      action: 'add_test'
    }.stringify_keys)
  end
end
