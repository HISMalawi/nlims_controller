# frozen_string_literal: true

# Add columns to specimen
class AddColumnsToSpecimen < ActiveRecord::Migration[7.1]
  def change
    add_column :specimen, :source_system, :string unless column_exists?(:specimen, :source_system)
    add_column :specimen, :clinical_history, :text unless column_exists?(:specimen, :clinical_history)
    add_column :specimen, :lab_location, :string unless column_exists?(:specimen, :lab_location)
    add_index :specimen, :source_system, unique: false unless index_exists?(:specimen, :source_system)
    add_index :specimen, :lab_location, unique: false unless index_exists?(:specimen, :lab_location)
  end
end
