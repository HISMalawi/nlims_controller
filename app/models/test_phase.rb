# frozen_string_literal: true

# TestPhase model
class TestPhase < ApplicationRecord
  has_many :test_statuses, dependent: :restrict_with_error, class_name: 'TestStatus'
end
