# frozen_string_literal: true

# TestTypeSpecimenType model
class TesttypeSpecimentype < ApplicationRecord
  belongs_to :test_type, class_name: 'TestType', foreign_key: 'test_type_id'
  belongs_to :specimen_type, class_name: 'SpecimenType', foreign_key: 'specimen_type_id'
  has_paper_trail
end
