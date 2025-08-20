# frozen_string_literal: true

# Migration to add app column to status sync tracker table
class UpdateStatusSyncTracker < ActiveRecord::Migration[5.1]
  def change
    add_column :status_sync_trackers, :app, :string unless column_exists?(:status_sync_trackers, :app)
  end
end
