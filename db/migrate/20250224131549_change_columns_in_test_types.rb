# frozen_string_literal: true

# ChangeColumnsInTestTypes
class ChangeColumnsInTestTypes < ActiveRecord::Migration[7.1]
  def change
    change_column :test_types, :description, :text
  end
end
