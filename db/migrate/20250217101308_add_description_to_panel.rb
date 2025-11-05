# frozen_string_literal: true

# Migration to add description to panel
class AddDescriptionToPanel < ActiveRecord::Migration[7.1]
  def change
    add_column :panel_types, :description, :string
  end
end
