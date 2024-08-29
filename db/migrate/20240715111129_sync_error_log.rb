# frozen_string_literal: true

# SyncErrorLog for logging errors in syncing orders to EMR
class SyncErrorLog < ActiveRecord::Migration[5.1]
  unless ActiveRecord::Base.connection.table_exists?(:sync_error_logs)
    def up
      create_table :sync_error_logs do |t|
        t.string :error_message
        t.json :error_details
        t.timestamps
      end
      add_index :sync_error_logs, :error_message, name: 'idx_sync_error_log_on_error_message'
    end
  end

  def down
    drop_table :sync_error_logs
  end
end
