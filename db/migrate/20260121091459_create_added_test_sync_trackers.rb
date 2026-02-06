# frozen_string_literal: true

# AddedTestSyncTracker for tracking tests added to orders that need syncing
class CreateAddedTestSyncTrackers < ActiveRecord::Migration[5.1]
  unless ActiveRecord::Base.connection.table_exists?(:added_test_sync_trackers)
    def up
      create_table :added_test_sync_trackers do |t|
        t.string :tracking_number
        t.string :test_id
        t.boolean :sync_status, default: false
        t.string :app
        t.timestamps
      end

      add_index :added_test_sync_trackers, :tracking_number, name: 'idx_added_test_sync_on_tracking_number'
      add_index :added_test_sync_trackers, :test_id, name: 'idx_added_test_sync_on_test_id'
      add_index :added_test_sync_trackers, %i[tracking_number test_id app],
                name: 'idx_added_test_sync_on_tracking_test_app'
    end
  end

  def down
    drop_table :added_test_sync_trackers
  end
end
