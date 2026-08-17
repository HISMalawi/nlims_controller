# frozen_string_literal: true

# A single measured value a test reports: haemoglobin, a CD4 count, a
# qualitative reading. Results are recorded against indicators, never against
# the test type as a whole.
class Indicator < ApplicationRecord
  include DictionaryEntry

  self.national_code_prefix = "TI"

  VALUE_TYPES = [ "AutoComplete", "Free Text", "Numeric", "AlphaNumeric", "Rich Text" ].freeze

  has_many :indicator_ranges, dependent: :destroy
  has_many :test_type_indicators, dependent: :destroy
  has_many :test_types, through: :test_type_indicators

  validates :value_type, inclusion: { in: VALUE_TYPES }

  def self.delta_includes
    [ :indicator_ranges ]
  end
end
