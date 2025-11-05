# frozen_string_literal: true

# Add codes to test types
class AddCodesToTestTypes < ActiveRecord::Migration[7.1]
  def change
    add_column :test_types, :moh_code, :string
    add_column :test_types, :nlims_code, :string
    add_column :test_types, :loinc_code, :string
    add_column :test_types, :preferred_name, :string
    add_column :test_types, :scientific_name, :string
    add_index :test_types, :moh_code, unique: true
    add_index :test_types, :nlims_code, unique: true
    add_index :test_types, :loinc_code, unique: true
  end
end
