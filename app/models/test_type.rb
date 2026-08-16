# frozen_string_literal: true

# A test that can be ordered. Carries the specimens it accepts, the indicators
# it reports and, for cultures, the organisms it can isolate.
class TestType < ApplicationRecord
  include DictionaryEntry

  self.national_code_prefix = "TT"

  SEXES = %w[Both M F].freeze

  belongs_to :department, optional: true

  has_many :test_type_specimen_types, dependent: :destroy
  has_many :specimen_types, through: :test_type_specimen_types

  has_many :test_type_indicators, -> { order(:position) }, dependent: :destroy, inverse_of: :test_type
  has_many :indicators, through: :test_type_indicators

  has_many :test_type_organisms, dependent: :destroy
  has_many :organisms, through: :test_type_organisms

  has_many :test_panel_test_types, dependent: :destroy
  has_many :test_panels, through: :test_panel_test_types

  validates :performed_on_sex, inclusion: { in: SEXES }
end
