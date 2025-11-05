# frozen_string_literal: true

# Add codes to specimen_dispatch_type
class AddCodesToSpecimenDispatchType < ActiveRecord::Migration[7.1]
  def change
    add_column :specimen_dispatch_types, :short_name, :string
    add_column :specimen_dispatch_types, :moh_code, :string
    add_column :specimen_dispatch_types, :nlims_code, :string
    add_column :specimen_dispatch_types, :loinc_code, :string
    add_column :specimen_dispatch_types, :preferred_name, :string
    add_column :specimen_dispatch_types, :scientific_name, :string
    add_index :specimen_dispatch_types, :moh_code, unique: true
    add_index :specimen_dispatch_types, :nlims_code, unique: true
    add_index :specimen_dispatch_types, :loinc_code, unique: true
  end
end
