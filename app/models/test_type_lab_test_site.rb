# frozen_string_literal: true

# This model represents the relationship between test types and lab test sites.
class TestTypeLabTestSite < ApplicationRecord
  belongs_to :test_type
  belongs_to :lab_test_site
end
