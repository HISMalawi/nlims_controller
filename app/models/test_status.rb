# frozen_string_literal: true

# This is the model for the test status table
class TestStatus < ApplicationRecord
    include Codeable

    has_many :tests, dependent: :restrict_with_error, class_name: 'Test'
    has_many :test_status_trails, dependent: :restrict_with_error, class_name: 'TestStatusTrail'

    NLIMS_CODE_PREFIX = 'TS'

    def self.get_test_status_id(type)
        TestStatus.find_by(name: type)&.id
    end
end
