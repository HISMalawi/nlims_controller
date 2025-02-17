# frozen_string_literal: true

# Test model
class Test < ApplicationRecord
  belongs_to :test_types, class_name: 'TestType', foreign_key: 'test_type_id'
  belongs_to :test_status, class_name: 'TestStatus', foreign_key: 'test_status_id'
end
