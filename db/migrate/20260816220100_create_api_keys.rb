# frozen_string_literal: true

class CreateApiKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :api_keys do |t|
      t.references :api_client, null: false, foreign_key: true
      t.string :uuid, null: false, limit: 36

      # The public half of the token. Indexed so a request costs one lookup
      # instead of a digest comparison against every key on the node.
      t.string :prefix, null: false, limit: 16

      # SHA-256 of the whole token. The secret half is never stored.
      t.string :key_digest, null: false, limit: 64

      # Text rather than json: MariaDB reports a json column as longtext, and
      # Rails then casts the array with to_s instead of encoding it. The model
      # serialises explicitly so the column behaves the same on both engines.
      t.text :scopes, null: false
      t.datetime :expires_at
      t.datetime :revoked_at
      t.datetime :last_used_at
      t.string :issued_by

      t.timestamps
    end

    add_index :api_keys, :uuid, unique: true
    add_index :api_keys, :prefix, unique: true
    add_index :api_keys, :revoked_at
  end
end
