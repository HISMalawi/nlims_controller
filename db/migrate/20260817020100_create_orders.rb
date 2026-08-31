# frozen_string_literal: true

# Replaces the old `specimen` table. One row per sample submitted for testing.
class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.string :uuid, null: false, limit: 36
      t.string :tracking_number, null: false, limit: 32
      t.references :patient, null: false, foreign_key: true

      t.string :status, null: false, default: "requested", limit: 24
      t.string :priority, null: false, default: "routine", limit: 12

      # The three codes that follow a sample from end to end: who collected and
      # sent it, which laboratory executes it, and which section within that
      # laboratory.
      t.string :sending_facility_code, null: false, limit: 16
      t.string :receiving_lab_code, null: false, limit: 24
      t.string :lab_code, limit: 32

      t.references :specimen_type, foreign_key: true

      t.datetime :collected_at
      t.string :requested_by
      t.string :order_location
      t.text :clinical_history

      # Which system put this order in, and under which key.
      t.string :source_system, limit: 16
      t.references :source_client, foreign_key: { to_table: :api_clients }

      t.timestamps
    end

    add_index :orders, :uuid, unique: true
    add_index :orders, :tracking_number, unique: true
    add_index :orders, :status
    add_index :orders, %i[receiving_lab_code status]
    add_index :orders, %i[sending_facility_code created_at]
  end
end
