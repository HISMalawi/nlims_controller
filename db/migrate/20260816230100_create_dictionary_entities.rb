# frozen_string_literal: true

class CreateDictionaryEntities < ActiveRecord::Migration[8.1]
  # Every dictionary record carries the same spine: a uuid that crosses node
  # boundaries, a readable national code, a publication status, and the revision
  # that the replication cursor walks.
  def spine(table)
    table.string :uuid, null: false, limit: 36
    table.string :national_code, null: false, limit: 32
    table.string :name, null: false
    table.string :short_name
    table.text :description
    table.string :status, null: false, default: "draft", limit: 12
    table.bigint :revision, null: false, default: 0
    table.string :loinc_code, limit: 32
    table.string :moh_code, limit: 32
    table.datetime :deleted_at
    table.timestamps
  end

  def spine_indexes(name)
    add_index name, :uuid, unique: true
    add_index name, :national_code, unique: true
    add_index name, :revision
    add_index name, %i[status revision]
  end

  def change
    create_table :departments, &method(:spine)

    create_table :specimen_types, &method(:spine)

    create_table :drugs, &method(:spine)

    create_table :organisms, &method(:spine)

    create_table :test_panels, &method(:spine)

    create_table :indicators do |t|
      spine(t)
      t.string :unit, limit: 32
      # AutoComplete, Free Text, Numeric, AlphaNumeric, Rich Text
      t.string :value_type, null: false, default: "Free Text", limit: 20
    end

    create_table :test_types do |t|
      spine(t)
      t.references :department, foreign_key: true
      t.string :target_tat, limit: 32
      t.string :performed_on_sex, null: false, default: "Both", limit: 8
    end

    create_table :indicator_ranges do |t|
      t.references :indicator, null: false, foreign_key: true
      t.integer :age_min
      t.integer :age_max
      t.string :sex, null: false, default: "Both", limit: 8
      t.decimal :range_lower, precision: 16, scale: 4
      t.decimal :range_upper, precision: 16, scale: 4
      t.string :interpretation
      t.string :value
      t.timestamps
    end

    %i[departments specimen_types drugs organisms test_panels indicators test_types].each do |table|
      spine_indexes(table)
    end
  end
end
