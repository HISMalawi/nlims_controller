# frozen_string_literal: true

# CreateTrackingNumberHosts migration
class CreateTrackingNumberHosts < ActiveRecord::Migration[5.1]
  unless table_exists? :tracking_number_hosts
    def up
      create_table :tracking_number_hosts do |t|
        t.string :tracking_number
        t.string :host

        t.timestamps
      end
      add_index :tracking_number_hosts, :tracking_number, name: 'idx_tracking_number_hosts'
    end
  end

  def down
    drop_table :tracking_number_hosts
  end
end
