# frozen_string_literal: true

# status sync tracker for tracking the status syncing to EMR
class StatusSyncTracker < ActiveRecord::Migration[5.1]
  unless ActiveRecord::Base.connection.table_exists?(:status_sync_trackers)
    def up
      create_table :status_sync_trackers do |t|
        t.string :tracking_number
        t.string :test_id
        t.string :status
        t.datetime :time_updated
        t.boolean :sync_status, default: false
        t.timestamps
      end

      add_index :status_sync_trackers, :tracking_number, name: 'idx_status_sync_on_tracking_number'
      add_index :status_sync_trackers, :status, name: 'idx_status_sync_on_status'
      add_index :status_sync_trackers, %i[tracking_number status test_id], name: 'idx_status_sync_on_tracking_and_status'
    end
  end

  def down
    drop_table :status_sync_trackers
  end
end
