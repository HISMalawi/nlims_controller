# frozen_string_literal: true

# UpdateResultSyncTracker
class UpdateResultSyncTracker < ActiveRecord::Migration[5.1]
  def change
    add_column :results_sync_trackers, :app, :string
  end
end
