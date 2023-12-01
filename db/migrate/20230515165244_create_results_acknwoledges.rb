class CreateResultsAcknwoledges < ActiveRecord::Migration[5.1]
  def change
    unless table_exists?(:results_acknwoledges)
      create_table :results_acknwoledges do |t|
        t.string :tracking_number
        t.integer :test_id
        t.datetime :result_date
        t.string    :acknwoledged_by
        t.datetime :acknwoledged_at
        t.boolean    :acknwoledged_to_nlims
        t.timestamps
      end
    end
  end
end
