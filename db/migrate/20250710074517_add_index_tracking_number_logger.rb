# frozen_string_literal: true

# This migration adds an index on the chsu_tracking_number_order_id column in the TrackingNumberLogger table.
class AddIndexTrackingNumberLogger < ActiveRecord::Migration[7.1]
  def change
    return if index_exists?(:tracking_number_loggers, :chsu_tracking_number_order_id)

    add_index :tracking_number_loggers, :chsu_tracking_number_order_id
  end
end
