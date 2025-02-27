# frozen_string_literal: true

# Add measure types metadata
class AddMeasureTypesMetada < ActiveRecord::Migration[7.1]
  def change
    add_column :measure_types, :structure, :json

    measure_types = {
      'Numeric' => {
        description: 'A numeric measurement type',
        structure: {
          type: 'ranges',
          parameters: [
            { name: 'Age Range', type: 'range', values: [{ min: 'number' }, { max: 'number' }] },
            { name: 'Measure Range', type: 'range', values: [{ min: 'number' }, { max: 'number' }] },
            { name: 'Interpretation', type: 'string', values: 'interpretation' },
            { name: 'Sex', type: 'options', values: %w[Male Female Both] }
          ]
        }
      },
      'Free Text' => {
        description: 'A freely entered text value',
        structure: {
          type: 'free_text'
        }
      },
      'AlphaNumeric' => {
        description: 'A combination of letters and numbers',
        structure: {
          type: 'options',
          parameters: [
            { name: 'value', type: 'string', values: 'value' },
            { name: 'Interpretation', type: 'string', values: 'interpretation' }
          ]
        }
      },
      'Rich Text' => {
        description: 'Formatted text with styling options',
        structure: {
          type: 'rich_text'
        }
      },
      'AutoComplete' => {
        description: 'A combination of letters and numbers',
        structure: {
          type: 'options',
          parameters: [
            { name: 'value', type: 'string', values: 'value' },
            { name: 'Interpretation', type: 'string', values: 'interpretation' }
          ]
        }
      }
    }

    measure_types.each do |name, attrs|
      MeasureType.find_or_create_by(name:).update(attrs)
    end
  end
end
