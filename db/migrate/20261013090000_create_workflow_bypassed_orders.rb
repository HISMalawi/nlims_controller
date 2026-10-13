# frozen_string_literal: true

# Log of samples that were processed without going through the NLIMS order workflow
# (no order was ever created in specimen), so they can still be accounted for.
class CreateWorkflowBypassedOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :workflow_bypassed_orders do |t|
      t.string :tracking_number, null: false
      t.datetime :ordered_at, null: false
      t.string :specimen_type, null: false
      t.string :test_type, null: false
      t.string :ordering_facility, null: false
      t.string :ordered_by
      t.string :receiving_lab
      t.timestamps
    end

    add_index :workflow_bypassed_orders, :tracking_number, unique: true
    add_index :workflow_bypassed_orders, :ordered_at
    add_index :workflow_bypassed_orders, :specimen_type
    add_index :workflow_bypassed_orders, :test_type
    add_index :workflow_bypassed_orders, :ordering_facility
    add_index :workflow_bypassed_orders, :ordered_by
    add_index :workflow_bypassed_orders, :receiving_lab
    add_index :workflow_bypassed_orders, %i[ordered_at ordering_facility],
              name: 'index_workflow_bypassed_orders_on_ordered_at_and_facility'
  end
end
