# frozen_string_literal: true

# Migration to convert site_code_number to zero-padded string
class ConvertSiteCodeNumberToZeroPaddedString < ActiveRecord::Migration[7.1]
  def up
    # First, add a temporary column to store the padded values
    add_column :sites, :site_code_number_temp, :string, limit: 4

    # Update existing records with zero-padded values
    Site.find_each do |site|
      if site.site_code_number.present?
        padded_value = site.site_code_number.to_s.rjust(4, '0')
        site.update_column(:site_code_number_temp, padded_value)
      end
    end

    # Remove the old column
    remove_column :sites, :site_code_number

    # Rename the temp column to the original name
    rename_column :sites, :site_code_number_temp, :site_code_number
  end

  def down
    # Add back integer column
    add_column :sites, :site_code_number_temp, :integer

    # Convert padded strings back to integers
    Site.find_each do |site|
      site.update_column(:site_code_number_temp, site.site_code_number.to_i) if site.site_code_number.present?
    end

    # Remove string column
    remove_column :sites, :site_code_number

    # Rename back
    rename_column :sites, :site_code_number_temp, :site_code_number
  end
end
