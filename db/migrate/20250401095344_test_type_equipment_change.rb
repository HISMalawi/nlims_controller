# frozen_string_literal: true

# This is the migration for the test_type_equipment_change table
class TestTypeEquipmentChange < ActiveRecord::Migration[7.1]
  def change
    remove_column :test_types, :equipment_required, :string
  end
end
