# frozen_string_literal: true

# Each EMR and each SISLAB installation arrives with codes of its own. They live
# here instead of in the dictionary, so one laboratory's legacy naming never
# becomes a national fact.
#
# Replaces the old name_mappings table, which could only map text to text and
# had no idea which system the text came from.
class CreateExternalMappings < ActiveRecord::Migration[8.1]
  def change
    create_table :external_mappings do |t|
      t.string :system, null: false, limit: 32
      t.references :api_client, foreign_key: true
      t.string :entity_type, null: false, limit: 32
      t.string :entity_uuid, null: false, limit: 36
      t.string :external_code, null: false
      t.string :external_name

      t.timestamps
    end

    add_index :external_mappings, %i[system api_client_id entity_type external_code],
              unique: true, name: "idx_external_mappings_lookup", length: { external_code: 100 }
    add_index :external_mappings, :entity_uuid
  end
end
