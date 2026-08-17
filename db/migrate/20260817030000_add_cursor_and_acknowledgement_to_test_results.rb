# frozen_string_literal: true

# What an EMR polling for results needs.
#
# The cursor is a revision from the same locked counter the dictionary uses, not
# a timestamp: two results can be written in one order and become visible in
# another, and an EMR that moved its cursor past the faster one would never come
# back for the slower one. That is a lost result, which is the one failure this
# system exists to prevent.
class AddCursorAndAcknowledgementToTestResults < ActiveRecord::Migration[8.1]
  def change
    add_column :test_results, :revision, :bigint, null: false, default: 0

    # The receipt: the EMR has archived this reading. Deliberately outside the
    # revision, so confirming a result does not move the cursor and hand the
    # confirmation straight back to whoever sent it.
    add_column :test_results, :acknowledged_at, :datetime
    add_column :test_results, :acknowledged_by, :string

    add_index :test_results, :revision
  end
end
