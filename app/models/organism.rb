# frozen_string_literal: true

# An organism a culture can isolate.
class Organism < ApplicationRecord
  include DictionaryEntry

  self.national_code_prefix = "OR"

  has_many :organism_drugs, dependent: :destroy
  has_many :drugs, through: :organism_drugs

  has_many :test_type_organisms, dependent: :destroy
  has_many :test_types, through: :test_type_organisms
end
