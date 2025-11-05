# frozen_string_literal: true

# Add codes to drug
class AddCodesToDrug < ActiveRecord::Migration[7.1]
  def change
    add_column :drugs, :short_name, :string
    add_column :drugs, :moh_code, :string
    add_column :drugs, :nlims_code, :string
    add_column :drugs, :loinc_code, :string
    add_column :drugs, :preferred_name, :string
    add_column :drugs, :scientific_name, :string
    add_index :drugs, :moh_code, unique: true
    add_index :drugs, :nlims_code, unique: true
    add_index :drugs, :loinc_code, unique: true
  end
end
