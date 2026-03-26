# frozen_string_literal: true

# MlabClient model - reads from mlab database clients table
class MlabClient < MlabBase
  self.table_name = 'clients'

  belongs_to :mlab_person, foreign_key: 'person_id', class_name: 'MlabPerson'
  has_many :mlab_encounters, foreign_key: 'client_id', class_name: 'MlabEncounter'
  has_many :mlab_client_identifiers, foreign_key: 'client_id', class_name: 'MlabClientIdentifier'

  scope :not_voided, -> { where('clients.voided IS NULL OR clients.voided = 0') }
end
