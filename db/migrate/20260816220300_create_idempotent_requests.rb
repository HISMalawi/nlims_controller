# frozen_string_literal: true

class CreateIdempotentRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :idempotent_requests do |t|
      t.references :api_client, null: false, foreign_key: true
      t.string :idempotency_key, null: false, limit: 255
      t.string :endpoint, null: false

      # Digest of the body the key was first seen with. Reusing a key with a
      # different payload is a client bug, and answering it with the first
      # response would hide the bug rather than surface it.
      t.string :request_digest, null: false, limit: 64

      t.integer :response_status, null: false
      t.text :response_body, null: false

      t.datetime :created_at, null: false
    end

    add_index :idempotent_requests, %i[api_client_id idempotency_key], unique: true,
                                                                      name: "idx_idempotent_on_client_and_key"
    add_index :idempotent_requests, :created_at
  end
end
