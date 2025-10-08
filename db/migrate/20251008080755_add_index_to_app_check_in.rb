# frozen_string_literal: true

# Migration to add index to app_check_ins table
class AddIndexToAppCheckIn < ActiveRecord::Migration[7.1]
  def change
    add_index :app_check_ins, :site_id if !index_exists?(:app_check_ins, :site_id)
    add_index :app_check_ins, :check_in_time if !index_exists?(:app_check_ins, :check_in_time)
    add_index :app_check_ins, :name if !index_exists?(:app_check_ins, :name)
  end
end
