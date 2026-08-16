# frozen_string_literal: true

# What the sample is: sangue total, urina, expectoração.
class SpecimenType < ApplicationRecord
  include DictionaryEntry

  self.national_code_prefix = "SP"

  has_many :test_type_specimen_types, dependent: :destroy
  has_many :test_types, through: :test_type_specimen_types
end
