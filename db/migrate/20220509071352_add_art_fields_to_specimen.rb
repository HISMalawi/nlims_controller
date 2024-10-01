class AddArtFieldsToSpecimen < ActiveRecord::Migration[5.1]
  def change
    return if column_exists?(:specimen, :arv_number)
    return if column_exists?(:specimen, :art_regimen)

    add_column :specimen, :arv_number, :string
    add_column :specimen, :art_regimen, :string
  end
end
