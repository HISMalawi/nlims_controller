# frozen_string_literal: true

# SpecimenIdentificationDistribution model
class SpecimenIdentificationDistribution < ApplicationRecord
  self.table_name = 'spid_distributions'
  belongs_to :specimen_identification
  belongs_to :site
  validates :specimen_identification, presence: true
  validates :site, presence: true
end
