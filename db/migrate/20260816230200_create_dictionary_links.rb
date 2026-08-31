# frozen_string_literal: true

# Links carry no revision of their own. Changing one bumps the revision of the
# record that owns it, because the delta ships a test type with its specimens,
# indicators and organisms inline — a link that moved without its parent moving
# would never reach a local node.
class CreateDictionaryLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :test_type_specimen_types do |t|
      t.references :test_type, null: false, foreign_key: true
      t.references :specimen_type, null: false, foreign_key: true
      t.timestamps
    end
    add_index :test_type_specimen_types, %i[test_type_id specimen_type_id], unique: true,
                                                                            name: "idx_tt_specimen_unique"

    create_table :test_type_indicators do |t|
      t.references :test_type, null: false, foreign_key: true
      t.references :indicator, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :test_type_indicators, %i[test_type_id indicator_id], unique: true, name: "idx_tt_indicator_unique"

    create_table :test_type_organisms do |t|
      t.references :test_type, null: false, foreign_key: true
      t.references :organism, null: false, foreign_key: true
      t.timestamps
    end
    add_index :test_type_organisms, %i[test_type_id organism_id], unique: true, name: "idx_tt_organism_unique"

    create_table :test_panel_test_types do |t|
      t.references :test_panel, null: false, foreign_key: true
      t.references :test_type, null: false, foreign_key: true
      t.timestamps
    end
    add_index :test_panel_test_types, %i[test_panel_id test_type_id], unique: true, name: "idx_panel_tt_unique"

    create_table :organism_drugs do |t|
      t.references :organism, null: false, foreign_key: true
      t.references :drug, null: false, foreign_key: true
      t.timestamps
    end
    add_index :organism_drugs, %i[organism_id drug_id], unique: true, name: "idx_organism_drug_unique"
  end
end
