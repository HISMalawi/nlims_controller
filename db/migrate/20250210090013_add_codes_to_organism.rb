# frozen_string_literal: true

# Add codes to organism
class AddCodesToOrganism < ActiveRecord::Migration[7.1]
  def change
    add_column :organisms, :short_name, :string
    add_column :organisms, :moh_code, :string
    add_column :organisms, :nlims_code, :string
    add_column :organisms, :loinc_code, :string
    add_column :organisms, :preferred_name, :string
    add_column :organisms, :scientific_name, :string
    add_index :organisms, :moh_code, unique: true
    add_index :organisms, :nlims_code, unique: true
    add_index :organisms, :loinc_code, unique: true
  end
end
