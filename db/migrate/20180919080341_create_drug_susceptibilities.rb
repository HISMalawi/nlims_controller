class CreateDrugSusceptibilities < ActiveRecord::Migration[5.1]
  def change
    return if table_exists?(:drug_susceptibilities)
    create_table :drug_susceptibilities do |t|

      t.references :user
      t.references :test
      t.references :organisms
      t.references :drug
      t.string :zone
      t.string :interpretation
      t.timestamps
    end
  end
end