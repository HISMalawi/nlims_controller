# frozen_string_literal: true

# Add unit to test results
class AddUnitToTestResults < ActiveRecord::Migration[7.1]
  def change
    add_column :test_results, :unit, :string unless column_exists?(:test_results, :unit)
  end
end
