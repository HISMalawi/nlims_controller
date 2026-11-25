# frozen_string_literal: true

# ARV number of the patient the bypassed order belongs to; optional because not every test is an ART test
class AddArvNumberToWorkflowBypassedOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :workflow_bypassed_orders, :arv_number, :string, after: :receiving_lab
    add_index :workflow_bypassed_orders, :arv_number
  end
end
