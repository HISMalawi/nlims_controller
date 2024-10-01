# frozen_string_literal: ture

#  CreateNameMappings model
class CreateNameMappings < ActiveRecord::Migration[5.1]
  def change
    return if table_exists? :name_mappings

    create_table :name_mappings do |t|
      t.string :manually_created_name
      t.string :actual_name
      t.timestamps
    end
  end
end
