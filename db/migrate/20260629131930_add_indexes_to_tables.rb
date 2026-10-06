# frozen_string_literal: true

# This migration adds indexes to the specimen and tests tables to improve query performance.
class AddIndexesToTables < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    unless index_exists?(:specimen, %i[sending_facility date_created], name: 'idx_specimen_facility_date')
      add_index :specimen,
                %i[sending_facility date_created],
                name: 'idx_specimen_facility_date',
                algorithm: :inplace
    end

    return if index_exists?(:tests, %i[specimen_id test_status_id test_type_id], name: 'idx_tests_specimen_status_type')

    add_index :tests,
              %i[specimen_id test_status_id test_type_id],
              name: 'idx_tests_specimen_status_type',
              algorithm: :inplace
  end

  def down
    remove_index :specimen, name: 'idx_specimen_facility_date' if index_exists?(:specimen,
                                                                                %i[sending_facility date_created], name: 'idx_specimen_facility_date')

    remove_index :tests, name: 'idx_tests_specimen_status_type' if index_exists?(:tests,
                                                                                 %i[specimen_id test_status_id test_type_id], name: 'idx_tests_specimen_status_type')
  end
end
