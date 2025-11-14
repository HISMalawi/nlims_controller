# frozen_string_literal: true

# AddColumnsToOrganismDrug
class AddColumnsToOrganismDrug < ActiveRecord::Migration[7.1]
  def change
    remove_column :organism_drugs, :name
    remove_column :organism_drugs, :description
    add_column :organism_drugs, :drug_id, :integer
    add_column :organism_drugs, :organism_id, :integer
  end
end
