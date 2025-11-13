# frozen_string_literal: true

# Add codes to panel types
class AddCodesToPanelTypes < ActiveRecord::Migration[7.1]
  def change
    add_column :panel_types, :moh_code, :string
    add_column :panel_types, :nlims_code, :string
    add_column :panel_types, :loinc_code, :string
    add_column :panel_types, :preferred_name, :string
    add_column :panel_types, :scientific_name, :string
    add_index :panel_types, :moh_code, unique: true
    add_index :panel_types, :nlims_code, unique: true
    add_index :panel_types, :loinc_code, unique: true
  end
end
