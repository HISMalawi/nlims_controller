# frozen_string_literal: true

# Create order status sync trackers
class CreateOrderStatusSyncTrackers < ActiveRecord::Migration[5.1]
  unless ActiveRecord::Base.connection.table_exists?(:order_status_sync_trackers)
    def up
      create_table :order_status_sync_trackers do |t|
        t.string :tracking_number
        t.string :status
        t.boolean :sync_status, default: false

        t.timestamps
      end
      add_index :order_status_sync_trackers, %i[tracking_number status], name: 'idx_track_num_order_status'
      add_index :order_status_sync_trackers, :sync_status, name: 'idx_order_status_sync_trackers_sync_status'
    end
  end
  def down
    drop_table :order_status_sync_trackers
  end
end
