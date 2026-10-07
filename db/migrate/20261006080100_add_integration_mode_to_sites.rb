# frozen_string_literal: true

# Lets each site be monitored either through its local NLIMS (default) or through a central EMR instance.
class AddIntegrationModeToSites < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:sites, :integration_mode)
      add_column :sites, :integration_mode, :string, null: false, default: 'local_nlims'
    end
    add_reference :sites, :emr_instance, index: true unless column_exists?(:sites, :emr_instance_id)
    unless column_exists?(:sites, :integration_mode_changed_at)
      add_column :sites, :integration_mode_changed_at, :datetime
    end
    add_index :sites, :integration_mode unless index_exists?(:sites, :integration_mode)
  end
end
