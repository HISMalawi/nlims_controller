# frozen_string_literal: true

# This migration adds a column to the tests table to store the method of testing
class AddMethodOfTestingToTests < ActiveRecord::Migration[7.1]
  def change
    return if column_exists?(:tests, :method_of_testing)

    add_column :tests, :method_of_testing, :string
  end
end
