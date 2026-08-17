# frozen_string_literal: true

# Everything this node has to tell the national one, written in the same
# transaction as the change it describes.
#
# That is the whole point: an event produced afterwards — in an after_commit
# hook, a nightly sweep, a background job — is an event that goes missing every
# time the process dies in between, and "the result never reached the national
# node" is the failure this system exists to remove. Either both the change and
# its event are committed, or neither is.
#
# Replaces the four *_sync_trackers tables, which each recorded a different
# subset of what had been sent, none of them transactionally.
class CreateSyncOutbox < ActiveRecord::Migration[8.1]
  def change
    create_table :sync_outbox do |t|
      # What the national node deduplicates on. Resending a batch is safe and
      # expected: delivery is at-least-once, and the receiver makes it once.
      t.string :event_uuid, null: false, limit: 36

      # The thing the event is about — usually the order. Ordering is per
      # aggregate rather than global, so one sample stuck behind a bad event
      # never holds up another facility's work.
      t.string :aggregate_uuid, null: false, limit: 36
      t.bigint :sequence, null: false

      t.string :type, null: false, limit: 32

      # Text with a JSON coder rather than a json column: MariaDB reports json
      # as longtext, which quietly changes how Rails serialises it, and the
      # development database here is MariaDB while the compose stack is MySQL.
      t.text :payload, null: false

      t.datetime :occurred_at, null: false

      # Delivery bookkeeping. Nothing is ever deleted: a delivered row is the
      # proof it was sent, and a failed one has to stay visible in the queue
      # instead of disappearing into the logs.
      t.integer :attempts, null: false, default: 0
      t.datetime :next_attempt_at
      t.datetime :delivered_at
      t.string :last_error, limit: 1000

      t.timestamps
    end

    add_index :sync_outbox, :event_uuid, unique: true
    add_index :sync_outbox, %i[aggregate_uuid sequence], unique: true
    add_index :sync_outbox, %i[delivered_at next_attempt_at]
    add_index :sync_outbox, :type
  end
end
