# frozen_string_literal: true

# speciment_identification_status model
class SpecimenIdentificationStatus < ApplicationRecord
  self.table_name = 'spid_statuses'
  belongs_to :csig_status
  belongs_to :specimen_identification
end
