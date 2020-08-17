class CreateTestTypes < ActiveRecord::Migration[5.1]
  def change
    create_table :test_types do |t|
    	t.references :test_category
    	t.string :name, null: false
    	t.string :short_name, :limit => 200
    	t.string :targetTAT
			t.string :description
			t.string :prevalence_threshold
     	t.timestamps
    end
  end
end
