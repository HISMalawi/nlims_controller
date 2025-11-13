# frozen_string_literal: true

# TestTypeOrganism model
class TesttypeOrganism < ApplicationRecord
  belongs_to :test_type, class_name: 'TestType', foreign_key: 'test_type_id'
  belongs_to :organism, class_name: 'Organism', foreign_key: 'organism_id'
end
