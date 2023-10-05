# SPeciemen Identification migration
class CreateSpecimenIdentifications < ActiveRecord::Migration[5.1]
  def change
    create_table :specimen_identifications do |t|
      t.string :sequence_number
      t.string :base9_equivalent
      t.string :base9_zero_padded
      t.string :encrypted
      t.string :encrypted_zero_cleaned
      t.string :check_digit
      t.string :sin

      t.timestamps
    end
  end
end
