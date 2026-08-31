# frozen_string_literal: true

# Every transition an order or one of its tests has made, in one append-only
# table. Replaces the several `*_trails` tables, which each recorded a different
# subset with a different shape and none of which could answer "what happened to
# this sample" without four queries and a merge.
class CreateStatusEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :status_events do |t|
      t.string :uuid, null: false, limit: 36

      # The table the subject lives in — `orders` or `order_tests` — and its
      # uuid. A uuid rather than a foreign key because these events travel to
      # the national node, where local ids mean nothing.
      t.string :entity_type, null: false, limit: 24
      t.string :entity_uuid, null: false, limit: 36

      # Denormalised on purpose: the whole history of a sample, its order and
      # every test on it, is one index scan on the number an operator actually
      # types. The tracking number never changes, so it cannot go stale.
      t.string :tracking_number, null: false, limit: 32

      t.string :from_status, limit: 24
      t.string :to_status, null: false, limit: 24
      t.string :actor
      t.string :reason

      t.datetime :created_at, null: false
    end

    add_index :status_events, :uuid, unique: true
    add_index :status_events, %i[tracking_number created_at]
    add_index :status_events, %i[entity_uuid created_at]
    add_index :status_events, %i[entity_type to_status]
  end
end
