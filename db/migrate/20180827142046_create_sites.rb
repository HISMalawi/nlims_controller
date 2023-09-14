# frozen_string_literal: true

# migration to create sites
class CreateSites < ActiveRecord::Migration[5.1]
  def change
    unless table_exists?(:sites)
      create_table :sites do |t|
        t.string :name
        t.string :district
        t.float  :x
        t.float  :y
        t.string :region
        t.string :description
        t.boolean :enabled
        t.boolean :sync_status
        t.string :site_code
        t.string :application_port
        t.string :host_address
        t.string :couch_username
        t.string :couch_password
        t.timestamps
      end
    end
  end
end