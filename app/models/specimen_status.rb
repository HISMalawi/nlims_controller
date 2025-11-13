# frozen_string_literal: true

# SpecimenStatus
class SpecimenStatus < ApplicationRecord
  include Codeable

  has_many :specimen, class_name: 'Speciman', dependent: :restrict_with_error

  NLIMS_CODE_PREFIX = 'OS'

  def self.get_specimen_status_id(type)
    SpecimenStatus.find_by(name: type)&.id
  end
end
