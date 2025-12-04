# frozen_string_literal: true

# This migration adds an index on the test_id column in the TestResultTrail table.
class AddIndexToTestResultTrail < ActiveRecord::Migration[7.1]
  def change
    return if index_exists?(:test_result_trails, :test_id)
    return if index_exists?(:test_result_trails, :measure_id)
    return if index_exists?(:test_result_trails, %i[test_id measure_id])

    add_index :test_result_trails, :test_id
    add_index :test_result_trails, :measure_id
    add_index :test_result_trails, %i[test_id measure_id]
  end
end
