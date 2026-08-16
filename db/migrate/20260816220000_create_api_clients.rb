# frozen_string_literal: true

class CreateApiClients < ActiveRecord::Migration[8.1]
  def change
    create_table :api_clients do |t|
      t.string :uuid, null: false, limit: 36
      t.string :name, null: false
      t.string :kind, null: false
      t.string :facility_code
      t.string :lab_code
      t.boolean :active, null: false, default: true
      t.text :notes

      t.timestamps
    end

    add_index :api_clients, :uuid, unique: true
    add_index :api_clients, :kind
    add_index :api_clients, %i[facility_code lab_code]
  end
end
