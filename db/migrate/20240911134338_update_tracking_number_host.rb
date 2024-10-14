# frozen_string_literal: true

# Adds and rename columns in tracking_number_hosts table
class UpdateTrackingNumberHost < ActiveRecord::Migration[5.1]
  def change
    add_column :tracking_number_hosts, :source_app_uuid, :string
    rename_column :tracking_number_hosts, :host, :source_host
    add_column :tracking_number_hosts, :update_host, :string
    add_column :tracking_number_hosts, :update_app_uuid, :string
  end
end
