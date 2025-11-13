# frozen_string_literal: true

# Add columns to test_catalog_version
class AddChangeDetailsToTestCatalogVersion < ActiveRecord::Migration[7.1]
  def change
    add_column :test_catalog_versions, :version_details, :json
  end
end
