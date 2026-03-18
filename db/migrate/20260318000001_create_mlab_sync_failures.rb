class CreateMlabSyncFailures < ActiveRecord::Migration[7.1]
  def change
    create_table :mlab_sync_failures do |t|
      t.bigint :mlab_test_id, null: false
      t.string :tracking_number
      t.string :test_type_nlims_code
      t.string :site_name
      t.string :failure_stage, null: false # e.g., 'order_creation', 'test_creation', 'status_update', 'result_update'
      t.text :failure_reason, null: false
      t.text :payload_snapshot # JSON snapshot of the data that failed
      t.boolean :resolved, default: false
      t.datetime :resolved_at, precision: nil
      t.text :resolution_notes
      t.string :resolved_by
      t.integer :retry_count, default: 0
      t.datetime :last_retry_at, precision: nil
      t.timestamps null: false, precision: nil

      t.index :mlab_test_id
      t.index :tracking_number
      t.index :resolved
      t.index :site_name
      t.index %i[mlab_test_id failure_stage]
      t.index %i[site_name resolved]
      t.index :created_at
    end
  end
end
