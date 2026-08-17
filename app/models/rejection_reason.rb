# frozen_string_literal: true

# Why a sample could not be tested. Curated nationally so that "hemolisada"
# means the same thing, and can be counted, in every laboratory.
class RejectionReason < ApplicationRecord
  include DictionaryEntry

  self.national_code_prefix = "RJ"

  has_many :orders, dependent: :restrict_with_error
end
