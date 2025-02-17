# frozen_string_literal: true

# Test model
class Test < ApplicationRecord
  belongs_to :test_types, class_name: 'TestType', foreign_key: 'test_type_id'
end
