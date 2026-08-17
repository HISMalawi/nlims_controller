# frozen_string_literal: true

# What the national node has been sent, and what it did with it.
#
# Every event is stored before it is applied, and kept afterwards. That is what
# makes resending safe — the second copy of an event_uuid is recognised and
# ignored — and it is what lets an operator see why something did not arrive
# instead of hunting through a log file.
class CreateInboundEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :inbound_events do |t|
      t.string :event_uuid, null: false, limit: 36
      t.string :node_code, null: false, limit: 24

      t.string :aggregate_uuid, null: false, limit: 36
      t.bigint :sequence, null: false

      t.string :type, null: false, limit: 32
      t.text :payload, null: false
      t.datetime :occurred_at, null: false

      # pending until it can be applied — an event whose predecessor has not
      # arrived waits rather than being applied out of order.
      t.string :status, null: false, default: "pending", limit: 12
      t.datetime :received_at, null: false
      t.datetime :applied_at
      t.string :error_code, limit: 40
      t.string :error_message, limit: 1000

      t.timestamps
    end

    add_index :inbound_events, :event_uuid, unique: true

    # Two nodes can hold the same order — that is what a referral is — and each
    # numbers its own stream. The stream is therefore identified by the node as
    # well as the aggregate.
    add_index :inbound_events, %i[node_code aggregate_uuid sequence], unique: true,
              name: "index_inbound_events_on_stream"
    add_index :inbound_events, %i[status received_at]
  end
end
