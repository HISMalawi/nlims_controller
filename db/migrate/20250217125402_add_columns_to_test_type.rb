# frozen_string_literal: true

# This is the migration for adding columns to test_type table
class AddColumnsToTestType < ActiveRecord::Migration[7.1]
  def change
    add_column :test_types, :can_be_done_on_sex, :string
    rename_column :measure_ranges, :alphanumeric, :value
    rename_column :measure_ranges, :gender, :sex
  end
end
