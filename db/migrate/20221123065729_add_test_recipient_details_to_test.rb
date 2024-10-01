class AddTestRecipientDetailsToTest < ActiveRecord::Migration[5.1]
  def change
    return if column_exists?(:tests, :test_result_receipent_types)
    return if column_exists?(:tests, :result_given)
    return if column_exists?(:tests, :date_result_given)

    add_column :tests, :test_result_receipent_types, :string
    add_column :tests, :result_given, :boolean
    add_column :tests, :date_result_given, :date
  end
end
