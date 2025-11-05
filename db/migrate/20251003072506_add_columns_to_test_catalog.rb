# frozen_string_literal: true

# Migration to create the test_catalogs table
class AddColumnsToTestCatalog < ActiveRecord::Migration[7.1]
  def change
    change_table :test_catalog_versions do |t|
      t.json :catalog unless column_exists?(:test_catalog_versions, :catalog)
      t.string :status, default: 'pending', null: false unless column_exists?(:test_catalog_versions, :status)
      t.integer :creator unless column_exists?(:test_catalog_versions, :creator)
      t.integer :updated_by unless column_exists?(:test_catalog_versions, :updated_by)
      t.integer :approved_by unless column_exists?(:test_catalog_versions, :approved_by)
      t.integer :rejected_by unless column_exists?(:test_catalog_versions, :rejected_by)
      t.datetime :approved_at unless column_exists?(:test_catalog_versions, :approved_at)
      t.datetime :rejected_at unless column_exists?(:test_catalog_versions, :rejected_at)
      t.text :rejection_reason unless column_exists?(:test_catalog_versions, :rejection_reason)
      t.json :version_details unless column_exists?(:test_catalog_versions, :version_details)
    end

    add_index :test_catalog_versions, :status unless index_exists?(:test_catalog_versions, :status)
  end
end
