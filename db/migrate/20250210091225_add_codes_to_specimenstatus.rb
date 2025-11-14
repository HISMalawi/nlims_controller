# frozen_string_literal: true

# Add codes to specimenstatus
class AddCodesToSpecimenstatus < ActiveRecord::Migration[7.1]
  def change
    add_column :specimen_statuses, :short_name, :string
    add_column :specimen_statuses, :moh_code, :string
    add_column :specimen_statuses, :nlims_code, :string
    add_column :specimen_statuses, :loinc_code, :string
    add_column :specimen_statuses, :preferred_name, :string
    add_column :specimen_statuses, :scientific_name, :string
    add_column :specimen_statuses, :description, :string
    add_index :specimen_statuses, :moh_code, unique: true
    add_index :specimen_statuses, :nlims_code, unique: true
    add_index :specimen_statuses, :loinc_code, unique: true
  end
end
