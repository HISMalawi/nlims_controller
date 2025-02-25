# frozen_string_literal: true

# This migration creates the test_type_lab_test_sites table.
class CreateTestTypeLabTestSite < ActiveRecord::Migration[7.1]
  def change
    create_table :test_type_lab_test_sites do |t|
      t.references :test_type, null: false, foreign_key: true
      t.references :lab_test_site, null: false, foreign_key: true
      t.timestamps
    end
    add_index :test_type_lab_test_sites, %i[test_type_id lab_test_site_id], unique: true,
                                                                            name: 'index_test_type_and_lab_test_site'
  end
end
