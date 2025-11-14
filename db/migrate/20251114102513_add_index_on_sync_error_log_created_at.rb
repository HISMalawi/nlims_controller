class AddIndexOnSyncErrorLogCreatedAt < ActiveRecord::Migration[7.1]
  def change
    add_index :sync_error_logs, :created_at
  end
end
