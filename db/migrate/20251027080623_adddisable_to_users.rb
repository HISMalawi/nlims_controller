# frozen_string_literal: true

# AdddisableToUsers migration
class AdddisableToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :disabled, :boolean, default: false
  end
end
