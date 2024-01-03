# frozen_string_literal: true

# TrackingNumberTrail migration
class TrackingNumberTrail < ActiveRecord::Migration[5.1]
  def change
    create_table :tracking_number_trails do |t|
      t.string :date
      t.string :current_value
      t.timestamps
    end
  end
end
