class SpecimenDispatch < ActiveRecord::Migration[5.1]
  def change
    return if table_exists? :specimen_dispatches

    create_table :specimen_dispatches do |t|
      t.string :tracking_number
      t.string :dispatcher
      t.references :dispatcher_type
      t.datetime :date_dispatched
      t.timestamps
    end
  end
end
