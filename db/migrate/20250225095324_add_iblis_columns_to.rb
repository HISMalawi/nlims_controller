# frozen_string_literal: true

# AddIblisColumnsTo
class AddIblisColumnsTo < ActiveRecord::Migration[7.1]
  def change
    add_column :test_types, :iblis_mapping_name, :string
    add_column :specimen_types, :iblis_mapping_name, :string
    add_column :measures, :iblis_mapping_name, :string
  end
end
