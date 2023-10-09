# frozen_string_literal: true

#  system column to speciment_distributin model
class AddSytemColumnToSpecimentDistributin < ActiveRecord::Migration[5.1]
  def change
    add_column :spid_statuses, :system_name, :string
    add_column :spid_statuses, :site_name, :string
  end
end
