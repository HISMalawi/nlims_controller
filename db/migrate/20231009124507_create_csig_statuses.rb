# frozen_string_literal: true

# csig_status model
class CreateCsigStatuses < ActiveRecord::Migration[5.1]
  def change
    create_table :csig_statuses do |t|
      t.string :name
      t.string :description

      t.timestamps
    end
  end
end
