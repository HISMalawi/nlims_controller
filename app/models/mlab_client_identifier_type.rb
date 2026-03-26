# frozen_string_literal: true

# MlabClientIdentifierType model - reads from mlab database client_identifier_types table
class MlabClientIdentifierType < MlabBase
  self.table_name = 'client_identifier_types'

  has_many :mlab_client_identifiers, foreign_key: 'client_identifier_type_id', class_name: 'MlabClientIdentifier'

  scope :not_retired, -> { where('client_identifier_types.retired IS NULL OR client_identifier_types.retired = 0') }
end
