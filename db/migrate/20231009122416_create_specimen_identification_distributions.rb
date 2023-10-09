# frozen_string_literal: true

# SpecimenIdentificationDistribution migration
class CreateSpecimenIdentificationDistributions < ActiveRecord::Migration[5.1]
  def change
    create_table :spid_distributions do |t|
      t.references :specimen_identification
      t.references :site

      t.timestamps
    end
  end
end
