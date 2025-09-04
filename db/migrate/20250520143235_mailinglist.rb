# frozen_string_literal: true

# Reports migration
class Mailinglist < ActiveRecord::Migration[7.1]
  def change
    return if table_exists?(:mailinglists)

    create_table :mailinglists do |t|
      t.string :email
      t.string :name
      t.timestamps
    end
  end
end
