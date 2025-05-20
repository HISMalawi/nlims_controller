# frozen_string_literal: true

# Reports migration
class CreateReports < ActiveRecord::Migration[7.1]
  def change
    create_table :reports do |t|
      t.string :name
      t.json :data
      t.timestamps
    end
  end
end
