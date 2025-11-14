# frozen_string_literal: true

# Add codes to testcatalog
class AddCodesToTestcatalog < ActiveRecord::Migration[7.1]
  def change
    add_column :test_categories, :short_name, :string
    add_column :test_categories, :moh_code, :string
    add_column :test_categories, :nlims_code, :string
    add_column :test_categories, :loinc_code, :string
    add_column :test_categories, :preferred_name, :string
    add_column :test_categories, :scientific_name, :string
    add_index :test_categories, :moh_code, unique: true
    add_index :test_categories, :nlims_code, unique: true
    add_index :test_categories, :loinc_code, unique: true
  end
end
