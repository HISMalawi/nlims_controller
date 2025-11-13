# frozen_string_literal: true

# This model represents a lab test site.
class LabTestSite < ApplicationRecord
  has_many :test_type_lab_test_sites, class_name: 'TestTypeLabTestSite', dependent: :restrict_with_error
end
