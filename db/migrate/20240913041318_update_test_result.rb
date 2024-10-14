# frozen_string_literal: true

# This migration updates the test_results table to have a text type for the result column
class UpdateTestResult < ActiveRecord::Migration[7.1]
  def change
    change_column :test_results, :result, :text
  end
end
