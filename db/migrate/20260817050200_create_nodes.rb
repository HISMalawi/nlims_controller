# frozen_string_literal: true

# Which nodes exist, and when each was last heard from.
#
# A node that stops reporting is the thing the national operator most needs to
# see, and today there is no way to know: silence from a laboratory looks
# exactly like a laboratory with nothing to send. The heartbeat carries what the
# node itself is worried about — how far behind its dictionary is, how much is
# stuck in its outbox, and what it last failed on.
class CreateNodes < ActiveRecord::Migration[8.1]
  def change
    create_table :nodes do |t|
      t.string :node_code, null: false, limit: 24
      t.string :name
      t.string :version, limit: 32

      t.datetime :last_seen_at
      t.bigint :dictionary_cursor, null: false, default: 0
      t.integer :outbox_pending, null: false, default: 0
      t.integer :outbox_failing, null: false, default: 0
      t.string :last_error, limit: 1000

      t.timestamps
    end

    add_index :nodes, :node_code, unique: true
    add_index :nodes, :last_seen_at
  end
end
