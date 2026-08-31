# frozen_string_literal: true

# A laboratory stops carrying its unit's details and starts pointing at it, and
# gains the code the LIS knows it by.
#
# `source_code` is what mLab calls the laboratory. It is unique inside one mLab
# instance and nowhere else, so it is only ever meaningful next to the unit it
# belongs to — which is why the index is on the pair. `national_code` becomes
# nullable because a laboratory is now registered here first, on the strength of
# a sample arriving, and named by the capital afterwards.
class LabsBelongToFacilities < ActiveRecord::Migration[8.0]
  def up
    add_column :labs, :source_code, :string, limit: 64

    change_column_null :labs, :national_code, true

    remove_column :labs, :facility_name
    remove_column :labs, :district
    remove_column :labs, :province

    add_index :labs, %i[facility_code source_code], unique: true, name: "index_labs_on_facility_and_source_code"

    # The publication history is addressed by uuid; the code was only ever there
    # to read. A laboratory registered here has none yet, and refusing to record
    # that it was registered would be losing the one entry that says where it
    # came from.
    change_column_null :dictionary_status_changes, :national_code, true
  end

  def down
    DictionaryStatusChange.where(national_code: nil).delete_all
    change_column_null :dictionary_status_changes, :national_code, false

    remove_index :labs, name: "index_labs_on_facility_and_source_code"

    add_column :labs, :province, :string
    add_column :labs, :district, :string
    add_column :labs, :facility_name, :string

    Lab.where(national_code: nil).delete_all
    change_column_null :labs, :national_code, false

    remove_column :labs, :source_code
  end
end
