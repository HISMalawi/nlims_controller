# frozen_string_literal: true

class CreateSequences < ActiveRecord::Migration[8.1]
  # Named counters. One row per counter, so incrementing the dictionary
  # revision never blocks on a national code being allocated.
  SEEDS = %w[
    dictionary_revision
    national_code:TC
    national_code:SP
    national_code:TT
    national_code:TI
    national_code:TP
    national_code:OR
    national_code:DR
  ].freeze

  def up
    create_table :sequences do |t|
      t.string :name, null: false, limit: 64
      t.bigint :value, null: false, default: 0

      t.timestamps
    end

    add_index :sequences, :name, unique: true

    values = SEEDS.map { |name| "(#{connection.quote(name)}, 0, NOW(), NOW())" }.join(", ")
    execute("INSERT INTO sequences (name, value, created_at, updated_at) VALUES #{values}")
  end

  def down
    drop_table :sequences
  end
end
