# frozen_string_literal: true

# AddPrecisonToRanges
class AddPrecisonToRanges < ActiveRecord::Migration[7.1]
  def change
    change_column :measure_ranges, :range_lower, :decimal, precision: 10, scale: 3
    change_column :measure_ranges, :range_upper, :decimal, precision: 10, scale: 3
  end
end
