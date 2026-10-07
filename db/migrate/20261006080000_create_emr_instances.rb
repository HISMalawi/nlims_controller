# frozen_string_literal: true

# Central EMR deployments (e.g. MaHIS) that sites can be attached to instead of a local NLIMS.
# Many sites share one instance; credentials are encrypted with ActiveRecord encryption.
class CreateEmrInstances < ActiveRecord::Migration[7.1]
  def change
    create_table :emr_instances do |t|
      t.string :name, null: false
      t.string :emr_type, null: false, default: 'mahis_central'
      t.string :base_url, null: false
      t.string :health_path, null: false, default: '/api/v1/_health'
      t.string :version_path, default: '/api/v1/version'
      t.string :login_path, null: false, default: '/api/v1/lab/users/login'
      t.string :summary_path, null: false, default: '/api/v1/lab/orders/summary'
      t.string :username
      # Ciphertext from ActiveRecord encryption is longer than the plain value
      t.text :password
      t.integer :vl_concept_id
      t.boolean :verify_ssl, null: false, default: true
      t.integer :timeout_seconds, null: false, default: 15
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :emr_instances, :name, unique: true
  end
end
