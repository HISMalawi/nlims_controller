class LogFailedResult < ActiveRecord::Migration[7.1]
  def change
    return if table_exists?(:failed_test_updates)

    create_table :failed_test_updates do |t| 
      t.string :tracking_number
      t.string :test_name
      t.string :error_message
      t.string :time_from_source
      t.string :failed_step_status
      t.timestamps
    end
    add_index :failed_test_updates, %i[tracking_number test_name failed_step_status]
  end
end
