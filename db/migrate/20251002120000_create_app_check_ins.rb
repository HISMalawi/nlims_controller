# frozen_string_literal: true

# Migration to create app_check_ins table
class CreateAppCheckIns < ActiveRecord::Migration[6.1]
  def change
    create_table :app_check_ins do |t|
      t.references :site, null: false, foreign_key: true
      t.string :name, null: false
      t.string :ip_address, null: false
      t.datetime :check_in_time, null: false

      t.timestamps
    end
  end
end
