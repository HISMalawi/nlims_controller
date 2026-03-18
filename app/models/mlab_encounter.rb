# frozen_string_literal: true

# MlabEncounter model - reads from mlab database encounters table
class MlabEncounter < MlabBase
  self.table_name = 'encounters'

  belongs_to :mlab_client, foreign_key: 'client_id', class_name: 'MlabClient'
  belongs_to :mlab_facility, foreign_key: 'facility_id', class_name: 'MlabFacility', optional: true
  has_many :mlab_orders, foreign_key: 'encounter_id', class_name: 'MlabOrder'

  scope :not_voided, -> { where('encounters.voided IS NULL OR encounters.voided = 0') }
end
