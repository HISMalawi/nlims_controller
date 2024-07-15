# frozen_string_literal: true

# SyncErrorLog for logging errors in syncing orders to EMR
class SyncErrorLog < ActiveRecord::Migration[5.1]
  def change
    create_table :sync_error_logs do |t|
      t.string :error_message
      t.json :error_details
      t.timestamps
    end
  end
end
