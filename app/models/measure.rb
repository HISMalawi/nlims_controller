# frozen_string_literal: true

# Measure/ test indicator model
class Measure < ApplicationRecord
  include Codeable

  has_many :test_results, class_name: 'TestResult', dependent: :restrict_with_error
  belongs_to :measure_types, class_name: 'MeasureType', foreign_key: 'measure_type_id'

  NLIMS_CODE_PREFIX = 'TI'
end
