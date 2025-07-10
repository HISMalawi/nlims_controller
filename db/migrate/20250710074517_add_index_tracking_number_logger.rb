# frozen_string_literal: true

# This migration adds an index on the chsu_tracking_number_order_id column in the TrackingNumberLogger table.
class AddIndexTrackingNumberLogger < ActiveRecord::Migration[7.1]
  def change
    add_index :tracking_number_loggers, :chsu_tracking_number_order_id
  end
end
