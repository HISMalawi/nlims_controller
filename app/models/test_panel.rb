# frozen_string_literal: true

# A set of tests ordered together under one name.
class TestPanel < ApplicationRecord
  include DictionaryEntry

  self.national_code_prefix = "TP"

  has_many :test_panel_test_types, dependent: :destroy
  has_many :test_types, through: :test_panel_test_types
end
