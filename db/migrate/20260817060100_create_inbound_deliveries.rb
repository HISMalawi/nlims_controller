# frozen_string_literal: true

# Which node still has to be told about which event.
#
# A referred sample concerns two facilities at once: the one that took it and
# the one running the test. The national node is the only party that can see
# both, so it works out who is interested in each event as it applies it, and
# each node then pulls its own list.
#
# One row per node per event, rather than one queue read by everybody: a node
# that has been offline for a week must not force every other node to keep its
# history around, and each cursor moves on its own.
class CreateInboundDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :inbound_deliveries do |t|
      t.string :node_code, null: false, limit: 24
      t.references :inbound_event, null: false, foreign_key: true

      # The cursor a node walks. A revision from a locked counter, not a
      # timestamp and not the row id, for the same reason as everywhere else:
      # two rows committed out of turn would let a cursor step over one.
      t.bigint :revision, null: false

      t.datetime :created_at, null: false
    end

    add_index :inbound_deliveries, %i[node_code revision]
    add_index :inbound_deliveries, %i[node_code inbound_event_id], unique: true,
              name: "index_inbound_deliveries_on_node_and_event"
  end
end
