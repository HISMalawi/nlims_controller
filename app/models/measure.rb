# frozen_string_literal: true

# Measure/ test indicator model
class Measure < ApplicationRecord
  include Codeable

  has_many :test_results, class_name: 'TestResult', dependent: :restrict_with_error
  belongs_to :measure_type, class_name: 'MeasureType', foreign_key: 'measure_type_id'
  has_many :measure_ranges, class_name: 'MeasureRange', dependent: :restrict_with_error, inverse_of: :measure

  accepts_nested_attributes_for :measure_ranges

  NLIMS_CODE_PREFIX = 'TI'
end
