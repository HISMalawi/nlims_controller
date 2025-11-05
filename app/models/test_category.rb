# frozen_string_literal: true

# test category model or departments
class TestCategory < ApplicationRecord
  include Codeable

  has_many :test_types, class_name: 'TestType', dependent: :restrict_with_error
  has_paper_trail

  NLIMS_CODE_PREFIX = 'TC'
end
