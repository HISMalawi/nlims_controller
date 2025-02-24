# frozen_string_literal: true

# change_columns_in_specimen_types.rb
class ChangeColumnsInSpecimenTypes < ActiveRecord::Migration[7.1]
    def change
      change_column :specimen_types, :description, :text
    end
end
