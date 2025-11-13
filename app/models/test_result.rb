# frozen_string_literal: true

# TestResult Model
class TestResult < ApplicationRecord
  belongs_to :test, class_name: 'Test', foreign_key: 'test_id'
  belongs_to :measure, class_name: 'Measure', foreign_key: 'measure_id'
end
