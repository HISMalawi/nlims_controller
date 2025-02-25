# frozen_string_literal: true

# This migration adds columns to the test_types table.
class AddColumnsToTestTypes < ActiveRecord::Migration[7.1]
  def change
    add_column :test_types, :assay_format, :text
    add_column :test_types, :equipment_required, :string
    add_column :test_types, :hr_cadre_required, :string
  end
end
