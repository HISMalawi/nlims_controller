# frozen_string_literal: true

# MlabClientIdentifier model - reads from mlab database client_identifiers table
class MlabClientIdentifier < MlabBase
  self.table_name = 'client_identifiers'

  belongs_to :mlab_client, foreign_key: 'client_id', class_name: 'MlabClient'
  belongs_to :mlab_client_identifier_type, foreign_key: 'client_identifier_type_id',
                                           class_name: 'MlabClientIdentifierType'

  scope :not_voided, -> { where('client_identifiers.voided IS NULL OR client_identifiers.voided = 0') }

  def identifier_type
    mlab_client_identifier_type&.name
  end
end
