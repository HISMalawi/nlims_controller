# frozen_string_literal: true

# This migration adds a new column called "other_name" to the "sites" table in the database.
class AddOtherNameColumnToSites < ActiveRecord::Migration[7.1]
  def change
    # Add a new column "other_name, mahis_location_id,mahis_facility_code" of type string to the "sites" table.
    add_column :sites, :other_name, :string unless column_exists?(:sites, :other_name)
    add_column :sites, :mahis_location_id, :integer unless column_exists?(:sites, :mahis_location_id)
    add_column :sites, :mahis_facility_code, :string unless column_exists?(:sites, :mahis_facility_code)
    add_index :sites, :other_name unless index_exists?(:sites, :other_name)
    add_index :sites, :host_address unless index_exists?(:sites, :host_address)
    add_index :sites, :name unless index_exists?(:sites, :name)
    # Add index for combination of name and district columns to ensure uniqueness.
    add_index :sites, [:name, :district], unique: true unless index_exists?(:sites, [:name, :district])
    add_index :sites, [:other_name, :district], unique: true unless index_exists?(:sites, [:other_name, :district])
    # Add index for mahis_location_id and mahis_facility_code columns to ensure uniqueness.
    add_index :sites, [:mahis_location_id, :mahis_facility_code], unique: true unless index_exists?(:sites, [:mahis_location_id, :mahis_facility_code])
    add_index :sites, :mahis_location_id, unique: true unless index_exists?(:sites, :mahis_location_id)
    add_index :sites, :mahis_facility_code, unique: true unless index_exists?(:sites, :mahis_facility_code)
  end
end
