# frozen_string_literal: true

# CreateProductEquipments migration
class CreateProductEquipments < ActiveRecord::Migration[7.1]
  def change
    create_table :product_equipments do |t|
      t.references :product, null: false, foreign_key: true
      t.references :equipment, null: false, foreign_key: true

      t.timestamps
    end
  end
end
