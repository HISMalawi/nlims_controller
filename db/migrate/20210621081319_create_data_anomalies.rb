class CreateDataAnomalies < ActiveRecord::Migration[5.1]
  def change
    unless table_exists?(:data_anomalies)
      create_table :data_anomalies do |t|
        t.string :data_type
        t.string :data   
        t.string :site_name
        t.string :tracking_number
        t.string :couch_id
        t.datetime :date_created
        t.string :status     
        t.timestamps
      end
    end
  end
end
