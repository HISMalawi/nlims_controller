# frozen_string_literal: true

# Remove unique indexes from measures
class RemoveUniqueIndexesFromMeasures < ActiveRecord::Migration[7.1]
  def change
    remove_index :measures, column: :moh_code if index_exists?(:measures, :moh_code)
    remove_index :measures, column: :loinc_code if index_exists?(:measures, :loinc_code)
  end
end
