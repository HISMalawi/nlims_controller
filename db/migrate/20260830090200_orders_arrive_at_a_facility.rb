# frozen_string_literal: true

# An order arrives at the unit, not at a laboratory.
#
# An EMR raising a request knows the patient and the tests; which of the unit's
# laboratories runs them is a decision taken at the bench, when one of them
# claims the sample. So the unit is what an order must have, and the laboratory
# is what it acquires.
class OrdersArriveAtAFacility < ActiveRecord::Migration[8.0]
  def up
    add_column :orders, :receiving_facility_code, :string, limit: 16

    # Everything already here was raised at, and worked by, the same node.
    execute <<~SQL.squish
      UPDATE orders
         SET receiving_facility_code = COALESCE(sending_facility_code, receiving_lab_code)
       WHERE receiving_facility_code IS NULL
    SQL

    change_column_null :orders, :receiving_facility_code, false
    change_column_null :orders, :receiving_lab_code, true

    add_index :orders, %i[receiving_facility_code status]
    add_index :orders, %i[receiving_facility_code revision]
  end

  def down
    remove_index :orders, %i[receiving_facility_code revision]
    remove_index :orders, %i[receiving_facility_code status]

    execute <<~SQL.squish
      UPDATE orders
         SET receiving_lab_code = receiving_facility_code
       WHERE receiving_lab_code IS NULL
    SQL

    change_column_null :orders, :receiving_lab_code, false
    remove_column :orders, :receiving_facility_code
  end
end
