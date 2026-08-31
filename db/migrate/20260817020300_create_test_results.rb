# frozen_string_literal: true

# One reading, against one indicator. Replaces the old `test_indicator_values`.
#
# Rows are never rewritten. A correction is a new row, and the row it corrects
# is marked with `replaced_by_uuid` — by the time a value is corrected the
# national node may already have distributed the wrong one, and an overwrite
# leaves nothing to reconcile it against.
class CreateTestResults < ActiveRecord::Migration[8.1]
  def change
    create_table :test_results do |t|
      t.string :uuid, null: false, limit: 36
      t.references :order_test, null: false, foreign_key: true
      t.references :indicator, null: false, foreign_key: true

      # Text, not a decimal: an indicator may report a number, a titre, a
      # sensitivity or a paragraph, and the dictionary says which.
      t.text :value
      t.string :unit, limit: 32

      t.datetime :recorded_at, null: false
      t.string :recorded_by

      # Points forward, at the row that superseded this one, so following a
      # correction chain never needs a second query per step.
      t.string :replaced_by_uuid, limit: 36

      t.timestamps
    end

    add_index :test_results, :uuid, unique: true
    add_index :test_results, %i[order_test_id indicator_id]
    add_index :test_results, :replaced_by_uuid
    add_index :test_results, :recorded_at
  end
end
