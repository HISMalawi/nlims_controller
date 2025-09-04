# frozen_string_literal: true

# This migration comes from solidus_chsu_tracking_number (originally 20250414124031)
class CreateTrackingNumberLogger < ActiveRecord::Migration[7.1]
  def change
    return if table_exists?(:tracking_number_loggers)

    create_table :tracking_number_loggers do |t|
      t.string :tracking_number, null: false
      t.bigint :chsu_tracking_number_order_id, null: false
      t.timestamps
    end
    add_index :tracking_number_loggers, :tracking_number
  end
end
