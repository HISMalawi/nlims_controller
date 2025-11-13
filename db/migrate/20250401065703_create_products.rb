# frozen_string_literal: true

# Product migration
class CreateProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :products do |t|
      t.string :name
      t.string :description
      t.string :nlims_code
      t.string :moh_code
      t.string :loinc_code
      t.timestamps
    end
  end
end
