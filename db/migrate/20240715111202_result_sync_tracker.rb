# frozen_string_literal: true

# ResultSyncTracker for tracking the status of results syncing to EMR
class ResultSyncTracker < ActiveRecord::Migration[5.1]
  def change
    create_table :results_sync_trackers do |t|
      t.string :tracking_number
      t.string :test_id
      t.boolean :sync_status, default: false
      t.timestamps
    end
  end
end
