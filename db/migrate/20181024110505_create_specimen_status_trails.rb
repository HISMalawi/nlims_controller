class CreateSpecimenStatusTrails < ActiveRecord::Migration[5.1]
  def change
    return if table_exists?(:specimen_status_trails)
    
    create_table :specimen_status_trails do |t|
      t.references :specimen
    	t.references :specimen_status
    	t.datetime :time_updated
      t.string :who_updated_id
      t.string :who_updated_name
      t.string :who_updated_phone_number
      t.timestamps
    end
  end
end
