# frozen_string_literal: true

# This is the model for the specimen type table
class SpecimenType < ApplicationRecord
  include Codeable

  has_many :specimen, dependent: :restrict_with_error, class_name: 'Speciman'
  has_many :testtype_specimentypes, class_name: 'TesttypeSpecimentype'

  NLIMS_CODE_PREFIX = 'SP'

  def self.get_specimen_type_id(type)
    SpecimenType.find_by(name: type).id
  end
end
