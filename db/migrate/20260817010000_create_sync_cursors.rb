# frozen_string_literal: true

# Where this node has got to in somebody else's feed. Persisted so a restart
# mid-sync resumes instead of starting over.
class CreateSyncCursors < ActiveRecord::Migration[8.1]
  def change
    create_table :sync_cursors do |t|
      t.string :name, null: false, limit: 64
      t.bigint :value, null: false, default: 0
      t.datetime :last_synced_at
      t.datetime :last_attempted_at
      t.string :last_error, limit: 1000
      t.integer :consecutive_failures, null: false, default: 0

      t.timestamps
    end

    add_index :sync_cursors, :name, unique: true
  end
end
