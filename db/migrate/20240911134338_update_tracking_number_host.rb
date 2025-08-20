# frozen_string_literal: true

# Adds and rename columns in tracking_number_hosts table
class UpdateTrackingNumberHost < ActiveRecord::Migration[5.1]
  def change
    add_column :tracking_number_hosts, :source_app_uuid, :string unless column_exists?(:tracking_number_hosts, :source_app_uuid)
    rename_column :tracking_number_hosts, :host, :source_host if column_exists?(:tracking_number_hosts, :host)
    add_column :tracking_number_hosts, :update_host, :string unless column_exists?(:tracking_number_hosts, :update_host)
    add_column :tracking_number_hosts, :update_app_uuid, :string unless column_exists?(:tracking_number_hosts, :update_app_uuid)
  end
end
