# frozen_string_literal: true

# Add codes to measures
class AddCodesToMeasures < ActiveRecord::Migration[7.1]
  def change
    add_column :measures, :moh_code, :string
    add_column :measures, :nlims_code, :string
    add_column :measures, :loinc_code, :string
    add_column :measures, :preferred_name, :string
    add_column :measures, :scientific_name, :string
    add_index :measures, :moh_code, unique: true
    add_index :measures, :nlims_code, unique: true
    add_index :measures, :loinc_code, unique: true
  end
end
