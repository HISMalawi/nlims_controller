# frozen_string_literal: true

# Add codes to visit type
class AddCodesToVisitType < ActiveRecord::Migration[7.1]
  def change
    add_column :visit_types, :short_name, :string
    add_column :visit_types, :moh_code, :string
    add_column :visit_types, :nlims_code, :string
    add_column :visit_types, :loinc_code, :string
    add_column :visit_types, :preferred_name, :string
    add_column :visit_types, :scientific_name, :string
    add_index :visit_types, :moh_code, unique: true
    add_index :visit_types, :nlims_code, unique: true
    add_index :visit_types, :loinc_code, unique: true
  end
end
