# frozen_string_literal: true

# SpecimenStatus
class SpecimenStatus < ApplicationRecord
  def self.get_specimen_status_id(type)
    res = SpecimenStatus.where(name: type)
    return res[0]['id'] unless res.blank?
  end
end
