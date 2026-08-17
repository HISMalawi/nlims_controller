# frozen_string_literal: true

# A sample sent from one laboratory to another.
#
# The tracking number never changes: the clinic that took the sample goes on
# asking after the same number, whichever institution ends up running the test.
# What this table adds is who sent it where, and when each hand took it.
#
# The gap between dispatched_at and received_at is the transport time, which is
# the number nobody in the country can currently produce — samples leave a
# district laboratory and their arrival is a telephone call at best.
class CreateReferrals < ActiveRecord::Migration[8.1]
  def change
    create_table :referrals do |t|
      t.string :uuid, null: false, limit: 36
      t.references :order, null: false, foreign_key: true
      t.string :tracking_number, null: false, limit: 32

      t.string :from_facility_code, null: false, limit: 16
      t.string :from_lab_code, limit: 24

      # The facility code is the node code: routing between nodes goes by it,
      # and the national node has no other way to know which node to hand a
      # referred sample to. The lab code says which laboratory inside it.
      t.string :to_facility_code, null: false, limit: 16
      t.string :to_lab_code, null: false, limit: 24

      t.string :state, null: false, default: "dispatched", limit: 12

      t.datetime :dispatched_at, null: false
      t.datetime :received_at
      t.datetime :rejected_at
      t.references :rejection_reason, foreign_key: true

      t.string :courier
      t.text :remarks

      t.timestamps
    end

    add_index :referrals, :uuid, unique: true
    add_index :referrals, :tracking_number
    add_index :referrals, %i[to_facility_code state]
    add_index :referrals, %i[from_facility_code dispatched_at]
  end
end
