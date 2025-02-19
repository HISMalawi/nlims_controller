# frozen_string_literal: true

# TestTypeMeasure model
class TesttypeMeasure < ApplicationRecord
  belongs_to :test_type, class_name: 'TestType', foreign_key: 'test_type_id'
  belongs_to :measure, class_name: 'Measure', foreign_key: 'measure_id'
end
