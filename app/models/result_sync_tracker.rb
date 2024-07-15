# frozen_string_literal: true

# ResultSyncTracker for tracking the status of results syncing to EMR
class ResultSyncTracker < ApplicationRecord
  self.table_name = 'results_sync_trackers'
end
