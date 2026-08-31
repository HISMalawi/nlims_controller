# frozen_string_literal: true

# Why a sample could not be tested: haemolysed, insufficient volume, wrong
# container, unlabelled.
#
# A dictionary entry rather than a free text field on the order, because the
# reason is the single most useful thing the laboratory ever tells the clinic —
# a facility whose samples are rejected for the same reason forty times a month
# has a problem that free text can never surface. It travels down the same
# replication feed as everything else, so every node offers the same list.
class CreateRejectionReasons < ActiveRecord::Migration[8.1]
  def change
    create_table :rejection_reasons do |t|
      t.string :uuid, null: false, limit: 36
      t.string :national_code, null: false, limit: 32
      t.string :name, null: false
      t.string :short_name
      t.text :description
      t.string :status, null: false, default: "draft", limit: 12
      t.bigint :revision, null: false, default: 0
      t.string :loinc_code, limit: 32
      t.string :moh_code, limit: 32
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :rejection_reasons, :uuid, unique: true
    add_index :rejection_reasons, :national_code, unique: true
    add_index :rejection_reasons, :revision
    add_index :rejection_reasons, %i[status revision]

    add_reference :orders, :rejection_reason, foreign_key: true
  end
end
