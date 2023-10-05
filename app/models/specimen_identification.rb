class SpecimenIdentification < ApplicationRecord
  validates :sequence_number, presence: true, uniqueness: true
  validates :base9_equivalent, presence: true, uniqueness: true
  validates :base9_zero_padded, presence: true, uniqueness: true
  validates :encrypted, presence: true, uniqueness: true
  validates :sin, presence: true, uniqueness: true
  validates :check_digit, presence: true
  validates :encrypted_zero_cleaned, presence: true, uniqueness: true
end
