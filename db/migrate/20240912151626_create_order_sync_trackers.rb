# frozen_string_literal: true

#  This migration creates the 'order_sync_trackers' table.
class CreateOrderSyncTrackers < ActiveRecord::Migration[7.1]
  def change
    create_table :order_sync_trackers do |t|
      t.string :tracking_number
      t.boolean :synced, default: false
      t.timestamps
    end
    add_index :order_sync_trackers, :tracking_number, unique: true
  end
end
