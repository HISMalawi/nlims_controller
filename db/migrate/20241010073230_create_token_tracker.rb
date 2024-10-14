# frozen_string_literal: true

# # Migration to create token tracker table
class CreateTokenTracker < ActiveRecord::Migration[7.1]
  def change
    return if table_exists?(:token_trackers)

    create_table :token_trackers do |t|
      t.string :username
      t.string :token
      t.timestamps
    end
    add_index :token_trackers, :username
  end
end
