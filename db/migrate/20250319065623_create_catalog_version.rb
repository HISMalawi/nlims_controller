# frozen_string_literal: true

# This migration creates the catalog_versions table.
class CreateCatalogVersion < ActiveRecord::Migration[7.1]
  def change
    create_table :test_catalog_versions do |t|
      t.string :version
      t.json :catalog
      t.integer :creator
      t.integer :updated_by
      t.timestamps
    end
    add_index :test_catalog_versions, :version, unique: true
    add_index :test_catalog_versions, :creator
  end
end
