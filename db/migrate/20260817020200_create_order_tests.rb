# frozen_string_literal: true

# One test requested on one sample. Replaces the old `tests` table.
class CreateOrderTests < ActiveRecord::Migration[8.1]
  def change
    create_table :order_tests do |t|
      t.string :uuid, null: false, limit: 36
      t.references :order, null: false, foreign_key: true
      t.references :test_type, null: false, foreign_key: true

      # The panel this test came in on, when it was ordered as part of one. Kept
      # so a panel ordered as a whole can still be reported as a whole, while
      # each test inside it moves through the states on its own.
      t.references :test_panel, foreign_key: true

      t.string :status, null: false, default: "pending", limit: 24
      t.string :method_of_testing, limit: 64

      t.timestamps
    end

    add_index :order_tests, :uuid, unique: true
    add_index :order_tests, %i[order_id test_type_id]
    add_index :order_tests, :status
  end
end
