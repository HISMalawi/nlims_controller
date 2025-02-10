# frozen_string_literal: true

# Add codes to teststatus
class AddCodesToTeststatus < ActiveRecord::Migration[7.1]
  def change
    add_column :test_statuses, :short_name, :string
    add_column :test_statuses, :moh_code, :string
    add_column :test_statuses, :nlims_code, :string
    add_column :test_statuses, :loinc_code, :string
    add_column :test_statuses, :preferred_name, :string
    add_column :test_statuses, :scientific_name, :string
    add_column :test_statuses, :description, :string
    add_index :test_statuses, :moh_code, unique: true
    add_index :test_statuses, :nlims_code, unique: true
    add_index :test_statuses, :loinc_code, unique: true
  end
end
