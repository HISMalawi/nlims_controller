# frozen_string_literal: true

# The health facility becomes the thing a node is.
#
# A node used to be a laboratory, on the assumption that one installation served
# one. It does not: an mLab instance serves every laboratory in the unit under
# its own code, and they all reach the network through the same node. So the
# unit is what the installation is told it is, and the laboratories hang off it.
#
# The unit is a dictionary entity like any other — the capital owns it, it rides
# the same feed and the same revision sequence, and it gets the dictionary
# screens for nothing.
class CreateFacilities < ActiveRecord::Migration[8.0]
  def change
    create_table :facilities do |t|
      t.string :uuid, limit: 36, null: false
      t.string :national_code, limit: 32
      t.string :name, null: false
      t.string :short_name
      t.text :description
      t.string :status, limit: 12, null: false, default: "draft"
      t.string :loinc_code, limit: 32
      t.string :moh_code, limit: 32
      t.string :district
      t.string :province
      t.string :phone, limit: 32
      t.bigint :revision, null: false, default: 0
      t.datetime :deleted_at
      t.timestamps

      t.index :uuid, unique: true
      t.index :national_code, unique: true
      t.index :revision
      t.index %i[status revision]
      t.index %i[province district]
    end
  end
end
