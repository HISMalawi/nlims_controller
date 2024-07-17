# frozen_string_literal: true

# status sync tracker for tracking the status syncing to EMR
class StatusSyncTracker < ActiveRecord::Migration[5.1]
  def change
    create_table :status_sync_trackers do |t|
      t.string :tracking_number
      t.string :status
      t.datetime :time_updated
      t.boolean :sync_status, default: false
      t.timestamps
    end

    add_index :status_sync_trackers, :tracking_number, name: 'idx_status_sync_on_tracking_number'
    add_index :status_sync_trackers, :status, name: 'idx_status_sync_on_status'
    add_index :status_sync_trackers, %i[tracking_number status], name: 'idx_status_sync_on_tracking_and_status'
  end
end
