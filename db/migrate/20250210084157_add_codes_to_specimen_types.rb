# frozen_string_literal: true

# Add codes to specimen types
class AddCodesToSpecimenTypes < ActiveRecord::Migration[7.1]
  def change
    add_column :specimen_types, :moh_code, :string
    add_column :specimen_types, :nlims_code, :string
    add_column :specimen_types, :loinc_code, :string
    add_column :specimen_types, :preferred_name, :string
    add_column :specimen_types, :scientific_name, :string
    add_index :specimen_types, :moh_code, unique: true
    add_index :specimen_types, :nlims_code, unique: true
    add_index :specimen_types, :loinc_code, unique: true
  end
end
