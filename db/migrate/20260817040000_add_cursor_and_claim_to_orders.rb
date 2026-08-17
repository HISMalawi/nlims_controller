# frozen_string_literal: true

# What a laboratory needs to pull its own work and take it.
#
# The cursor is a revision from a locked counter for the same reason the
# dictionary's and the results' are: two orders can be written in one order and
# become visible in another, and a laboratory that moved its cursor past the
# faster one would never come back for the slower one.
#
# The claim is a pair of columns rather than a status, because a status says
# what is happening to the sample and this says who is holding it. Exclusivity
# is enforced by claiming with a conditional update, not by reading the column
# first and writing it after.
class AddCursorAndClaimToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :revision, :bigint, null: false, default: 0
    add_column :orders, :claimed_at, :datetime
    add_column :orders, :claimed_by_lab_code, :string, limit: 24

    add_index :orders, :revision
    add_index :orders, %i[receiving_lab_code revision]
  end
end
