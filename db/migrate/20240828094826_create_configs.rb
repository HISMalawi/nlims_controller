# frozen_string_literal: true

# CreateConfigs for creating configs table
class CreateConfigs < ActiveRecord::Migration[5.1]
  unless ActiveRecord::Base.connection.table_exists?(:configs)
    def up
      create_table :configs do |t|
        t.string :config_type, null: false, index: true, unique: true
        t.json :configs
        t.timestamps
      end
    end
  end
  def down
    drop_table :configs
  end
end
