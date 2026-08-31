# frozen_string_literal: true

# What a request names, kept as it was named.
#
# Until now every clinical term on a request had to resolve to an active
# dictionary entry or the whole request was refused. The national dictionary is
# not consolidated, so that rule was refusing real work: a laboratory could not
# record an exam it runs every day because the catalogue did not have it yet.
#
# Each reference now stores the name and the code it arrived with alongside the
# foreign key. The key is filled when the term is recognised and left null when
# it is not, so the same row reads the same way either way, and a term can be
# linked to the dictionary later without the reading being re-entered.
class RelaxDictionaryReferences < ActiveRecord::Migration[8.1]
  def change
    change_table :order_tests, bulk: true do |t|
      t.string :test_name
      t.string :test_code, limit: 64
      t.string :panel_name
      t.string :panel_code, limit: 64
    end
    change_column_null :order_tests, :test_type_id, true
    add_index :order_tests, :test_name

    change_table :orders, bulk: true do |t|
      t.string :specimen_name
      t.string :specimen_code, limit: 64
      t.string :rejection_name
      t.string :rejection_code, limit: 64
    end

    change_table :test_results, bulk: true do |t|
      t.string :indicator_name
      t.string :indicator_code, limit: 64
    end
    change_column_null :test_results, :indicator_id, true

    change_table :referrals, bulk: true do |t|
      t.string :rejection_name
      t.string :rejection_code, limit: 64
    end

    # Derived from the register now, not sent by the client, and a laboratory
    # that has not been given a facility code yet still has to be referable.
    change_column_null :referrals, :to_facility_code, true
    change_column_null :orders, :sending_facility_code, true
  end
end
