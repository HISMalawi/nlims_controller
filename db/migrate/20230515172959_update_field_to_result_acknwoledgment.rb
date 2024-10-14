# frozen_string_literal: true

class UpdateFieldToResultAcknwoledgment < ActiveRecord::Migration[5.1]
  def change
    return if column_exists?(:results_acknwoledges, :acknowledgment_level)

    add_column :results_acknwoledges, :acknowledgment_level, :int
  end
end
