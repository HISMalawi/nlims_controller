# frozen_string_literal: true

# CreateJoinTableUsersRoles migration
class CreateJoinTableUsersRoles < ActiveRecord::Migration[7.1]
  def change
    create_join_table :users, :roles do |t|
      t.index [:user_id, :role_id], unique: true
      t.index [:role_id, :user_id]
    end
  end
end
