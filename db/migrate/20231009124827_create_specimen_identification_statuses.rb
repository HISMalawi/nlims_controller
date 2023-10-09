# frozen_string_literal: true

# SpecimenIdentificationStatus model
class CreateSpecimenIdentificationStatuses < ActiveRecord::Migration[5.1]
  def change
    create_table :spid_statuses do |t|
      t.references :csig_status
      t.references :specimen_identification

      t.timestamps
    end
  end
end
