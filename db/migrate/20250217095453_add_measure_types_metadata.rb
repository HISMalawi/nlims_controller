# frozen_string_literal: true

# Add measure types metadata
class AddMeasureTypesMetadata < ActiveRecord::Migration[7.1]
    def change
      add_column :measure_types, :description, :string

      measure_types = {
        'Numeric' => 'A numeric measurement type',
        'Free Text' => 'A freely entered text value',
        'AlphaNumeric' => 'A combination of letters and numbers',
        'Rich Text' => 'Formatted text with styling options'
      }

      measure_types.each do |name, description|
        MeasureType.find_or_create_by(name:) do |mt|
          mt.description = description
        end
      end
    end
end
