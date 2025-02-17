# frozen_string_literal: true

# TestType model
class TestType < ApplicationRecord
    include Codeable
    has_many :test_results, dependent: :restrict_with_error
    has_many :tests, dependent: :restrict_with_error
    belongs_to :test_category, class_name: 'TestCategory', foreign_key: 'test_category_id'

    NLIMS_CODE_PREFIX = 'TT'

    def self.get_test_type_id(type)
        TestType.find_by(name: type)&.id
    end
end
