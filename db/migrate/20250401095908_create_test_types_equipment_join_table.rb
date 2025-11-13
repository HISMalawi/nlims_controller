# frozen_string_literal: true

# This is the migration for the test_types_equipment join table
class CreateTestTypesEquipmentJoinTable < ActiveRecord::Migration[7.1]
  def change
    create_table :equipment_test_types, id: false do |t| # No primary key needed
      t.references :test_type, null: false, foreign_key: true
      t.references :equipment, null: false, foreign_key: true
    end
  end
end
