# frozen_string_literal: true

# AddDistributedColumnsToSpecimentIdentification migration
class AddDistributedColumnsToSpecimentIdentification < ActiveRecord::Migration[5.1]
  def change
    add_column :specimen_identifications, :distributed, :boolean, default: false
  end
end
