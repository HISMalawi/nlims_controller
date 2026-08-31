# frozen_string_literal: true

class CreatePatients < ActiveRecord::Migration[8.1]
  def change
    create_table :patients do |t|
      t.string :uuid, null: false, limit: 36

      # The national identifier. Unique where present, so the same person
      # arriving from two facilities becomes one patient rather than two — MySQL
      # allows repeated NULLs, which is what a patient with no NID needs.
      t.string :national_id, limit: 32

      t.string :name, null: false
      t.string :sex, null: false, default: "Unknown", limit: 8
      t.date :birthdate
      t.string :phone, limit: 32

      t.timestamps
    end

    add_index :patients, :uuid, unique: true
    add_index :patients, :national_id, unique: true
    add_index :patients, :name
  end
end
