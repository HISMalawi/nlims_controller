# frozen_string_literal: true

# Migration to change column to text type
class UpdateSyncError < ActiveRecord::Migration[7.1]
  def change
    remove_index :sync_error_logs, :error_message if index_exists?(:sync_error_logs, :error_message)
    change_column :sync_error_logs, :error_message, :text
  end
end
