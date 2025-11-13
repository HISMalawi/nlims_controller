# frozen_string_literal: true

# This is the migration for the predefined results table
class CreatePredefinedResults < ActiveRecord::Migration[7.1]
  def change
    create_table :predefined_results do |t|
      t.string :name
      t.string :short_name
      t.string :description
      t.string :nlims_code
      t.string :loinc_code
      t.string :moh_code
      t.string :preferred_name
      t.string :scientific_name
      t.timestamps
    end
  end
end
