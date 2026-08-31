# frozen_string_literal: true

class CreateRequestAudits < ActiveRecord::Migration[8.1]
  def change
    create_table :request_audits do |t|
      # Null on a rejected request: a caller with a bad key still has to leave
      # a trace, which is exactly when there is no client to point at.
      t.references :api_client, foreign_key: true
      t.references :api_key, foreign_key: true

      t.string :request_method, null: false, limit: 10
      t.string :path, null: false
      t.integer :status, null: false
      t.integer :duration_ms
      t.string :ip, limit: 45
      t.string :request_id, limit: 36
      t.string :error_code

      t.datetime :created_at, null: false
    end

    add_index :request_audits, :created_at
    add_index :request_audits, %i[api_client_id created_at]
    add_index :request_audits, :error_code
  end
end
