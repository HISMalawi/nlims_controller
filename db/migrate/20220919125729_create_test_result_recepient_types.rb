class CreateTestResultRecepientTypes < ActiveRecord::Migration[5.1]
  def change
    unless table_exists?(:test_result_recepient_types)
      create_table :test_result_recepient_types do |t|
        t.string :name
        t.string :description
        t.timestamps
      end
    end
  end
end

