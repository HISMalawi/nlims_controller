# frozen_string_literal: true

# Add app_uuid to users table
class UpdateUser < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :app_uuid, :string
  end
end
