# frozen_string_literal: true

# This miggration creates the test_result_trails table
class CreateTestResultTrails < ActiveRecord::Migration[7.1]
  def change
    create_table :test_result_trails do |t|
      t.integer :measure_id
      t.integer :test_id
      t.text :old_result
      t.text :new_result
      t.string :old_device_name
      t.string :new_device_name
      t.string :old_time_entered
      t.string :new_time_entered
      t.timestamps
    end
  end
end
