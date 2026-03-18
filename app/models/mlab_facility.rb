# frozen_string_literal: true

# MlabFacility model - reads from mlab database facilities table
class MlabFacility < MlabBase
  self.table_name = 'facilities'

  has_many :mlab_encounters, foreign_key: 'facility_id', class_name: 'MlabEncounter'

  scope :not_retired, -> { where('retired IS NULL OR retired = 0') }
end
