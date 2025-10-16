# frozen_string_literal: true

# Test model
class Test < ApplicationRecord
  belongs_to :test_type, class_name: 'TestType', foreign_key: 'test_type_id'
  belongs_to :test_status, class_name: 'TestStatus', foreign_key: 'test_status_id'
  belongs_to :speciman, class_name: 'Speciman', foreign_key: 'specimen_id'
  belongs_to :patient, class_name: 'Patient', foreign_key: 'patient_id'
  has_many :test_status_trail, class_name: 'TestStatusTrail'
  has_many :test_results, class_name: 'TestResult'
end
