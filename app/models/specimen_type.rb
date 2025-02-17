# frozen_string_literal: true

# This is the model for the specimen type table
class SpecimenType < ApplicationRecord
  include Codeable

  has_many :specimens, dependent: :restrict_with_error

  NLIMS_CODE_PREFIX = 'SP'

  def self.get_specimen_type_id(type)
    SpecimenType.find_by(name: type).id
  end
end
