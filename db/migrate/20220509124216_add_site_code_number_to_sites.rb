class AddSiteCodeNumberToSites < ActiveRecord::Migration[5.1]
  def change
    return if column_exists?(:sites, :site_code_number)

    add_column :sites, :site_code_number, :integer
  end
end
