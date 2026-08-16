# frozen_string_literal: true

# A laboratory section: Bioquímica, Microbiologia, Banco de Sangue.
class Department < ApplicationRecord
  include DictionaryEntry

  self.national_code_prefix = "TC"

  has_many :test_types, dependent: :restrict_with_error
end
