# frozen_string_literal: true

# The register of laboratories, owned by the national node and replicated to
# every local one through the dictionary feed.
#
# It is a dictionary entity rather than a table of its own so that it travels on
# the machinery that already exists — one revision sequence, one cursor, one
# puller, one set of screens. What it adds to the shared spine is where the
# laboratory is: a node that knows the register does not have to be told the
# health facility of the laboratory it is referring a sample to.
class CreateLabs < ActiveRecord::Migration[8.1]
  def change
    create_table :labs do |t|
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

      # The health facility the laboratory sits in. A hospital with two
      # laboratories has two entries here that share a facility code, which is
      # the case the old facility/lab pair on every request never handled.
      t.string :facility_code, limit: 16
      t.string :facility_name
      t.string :district
      t.string :province
      t.string :phone, limit: 32

      t.timestamps
    end

    add_index :labs, :uuid, unique: true
    add_index :labs, :national_code, unique: true
    add_index :labs, :revision
    add_index :labs, %i[status revision]
    add_index :labs, :facility_code
  end
end
