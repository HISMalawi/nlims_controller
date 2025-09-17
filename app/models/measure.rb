# frozen_string_literal: true

# Measure/ test indicator model
class Measure < ApplicationRecord
  include Codeable

  has_many :test_results, class_name: 'TestResult', dependent: :restrict_with_error
  belongs_to :measure_type, class_name: 'MeasureType', foreign_key: 'measure_type_id'
  has_many :measure_ranges, class_name: 'MeasureRange', dependent: :restrict_with_error, inverse_of: :measure
  has_many :testtype_measures, class_name: 'TesttypeMeasure'
  has_paper_trail

  accepts_nested_attributes_for :measure_ranges

  NLIMS_CODE_PREFIX = 'TI'

  def as_json(options = {})
    super(options.merge(
      except: %i[measure_type_id],
      include: {
        measure_type: {},
        measure_ranges: {}
      }
    ))
  end
end
