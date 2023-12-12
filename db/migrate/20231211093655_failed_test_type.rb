class FailedTestType < ActiveRecord::Migration[5.1]
  def change
    create_table :failed_test_types do |t|
      t.string :test_type
      t.string :reason
      t.timestamps
    end
  end
end
