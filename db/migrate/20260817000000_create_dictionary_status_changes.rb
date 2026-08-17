# frozen_string_literal: true

# Who published what, and when. Without published versions to point at, the
# publication history is the only record of how the dictionary got to its
# current state, so it is kept for every transition rather than only for bulk
# promotions.
class CreateDictionaryStatusChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :dictionary_status_changes do |t|
      t.string :entity_type, null: false, limit: 32
      t.string :entity_uuid, null: false, limit: 36
      t.string :national_code, null: false, limit: 32
      t.string :from_status, limit: 12
      t.string :to_status, null: false, limit: 12
      t.bigint :revision
      t.string :actor
      t.string :reason

      t.datetime :created_at, null: false
    end

    add_index :dictionary_status_changes, :entity_uuid
    add_index :dictionary_status_changes, :created_at
    add_index :dictionary_status_changes, %i[entity_type to_status]
  end
end
