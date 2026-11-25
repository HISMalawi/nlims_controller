class AddMlabCallbackSettingsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :mlab_callback_base_url, :string
    add_column :users, :mlab_callback_token, :string
    add_column :users, :mlab_callback_enabled, :boolean, default: false, null: false
  end
end
