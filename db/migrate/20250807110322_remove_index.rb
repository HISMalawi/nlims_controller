class RemoveIndex < ActiveRecord::Migration[7.1]
  def change
    moh_code = index_exists?(:measures, :moh_code)
    loinc_code = index_exists?(:measures, :loinc_code)
    nlims_code = index_exists?(:measures, :nlims_code)
    test_types_nlims_code = index_exists?(:test_types, :nlims_code)
    test_types_moh_code = index_exists?(:test_types, :moh_code)
    test_types_loinc_code = index_exists?(:test_types, :loinc_code)

    remove_index :measures, column: :moh_code if moh_code
    remove_index :measures, column: :loinc_code if loinc_code
    remove_index :measures, column: :nlims_code if nlims_code
    remove_index :test_types, column: :nlims_code if test_types_nlims_code
    remove_index :test_types, column: :moh_code if test_types_moh_code
    remove_index :test_types, column: :loinc_code if test_types_loinc_code
  end
end
