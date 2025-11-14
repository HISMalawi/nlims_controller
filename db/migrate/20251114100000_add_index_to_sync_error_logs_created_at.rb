class AddIndexToSyncErrorLogsCreatedAt < ActiveRecord::Migration[5.1]
  def change
    return if index_exists?(:sync_error_logs, :created_at)

    add_index :sync_error_logs, :created_at
  end
end
