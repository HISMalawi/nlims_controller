class UpdateFieldToResultAcknwoledgment < ActiveRecord::Migration[5.1]
  def change
    return if column_exists?(:results_acknwoledges, :acknwoledment_level)

    add_column :results_acknwoledges, :acknwoledment_level, :int
  end
end
