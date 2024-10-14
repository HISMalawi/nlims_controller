# frozen_string_literal: true

class CreateTestResultRecepientTypes < ActiveRecord::Migration[5.1]
  def change
    return if table_exists?(:test_result_receipent_types)

    create_table :test_result_recepient_types do |t|
      t.string :name
      t.string :description
      t.timestamps
    end
  end
end
