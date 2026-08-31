# frozen_string_literal: true

# An antimicrobial a susceptibility test can report against.
class Drug < ApplicationRecord
  include DictionaryEntry

  self.national_code_prefix = "DR"

  has_many :organism_drugs, dependent: :destroy
  has_many :organisms, through: :organism_drugs
end
