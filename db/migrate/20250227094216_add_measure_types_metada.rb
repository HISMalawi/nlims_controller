# frozen_string_literal: true

# Add measure types metadata
class AddMeasureTypesMetada < ActiveRecord::Migration[7.1]
  def change
    add_column :measure_types, :structure, :json
  end
end
