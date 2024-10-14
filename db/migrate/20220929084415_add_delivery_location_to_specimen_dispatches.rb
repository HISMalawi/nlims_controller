# frozen_string_literal: true

class AddDeliveryLocationToSpecimenDispatches < ActiveRecord::Migration[5.1]
  def change
    return if column_exists?(:specimen_dispatches, :delivery_location)

    add_column :specimen_dispatches, :delivery_location, :string
  end
end
