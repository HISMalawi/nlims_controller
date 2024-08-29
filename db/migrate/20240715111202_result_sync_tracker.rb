# frozen_string_literal: true

# ResultSyncTracker for tracking the status of results syncing to EMR
class ResultSyncTracker < ActiveRecord::Migration[5.1]
  unless ActiveRecord::Base.connection.table_exists?(:results_sync_trackers)
    def up
      create_table :results_sync_trackers do |t|
        t.string :tracking_number
        t.string :test_id
        t.boolean :sync_status, default: false
        t.timestamps
      end

      add_index :results_sync_trackers, :tracking_number, name: 'idx_result_sync_on_tracking_number'
      add_index :results_sync_trackers, :test_id, name: 'idx_result_sync_on_test_id'
      add_index :results_sync_trackers, %i[tracking_number test_id], name: 'idx_result_sync_on_tracking_and_test_id'
    end
  end

  def down
    drop_table :results_sync_trackers
  end
end
