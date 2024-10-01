class CreateSpecimenDispatchTypes < ActiveRecord::Migration[5.1]
  def change
    return if table_exists? :specimen_dispatch_types

    create_table :specimen_dispatch_types do |t|
      t.string :name
      t.string :description
      t.timestamps
    end
  end
end
