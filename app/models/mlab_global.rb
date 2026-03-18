# frozen_string_literal: true

# Model for reading mlab global settings/configuration
class MlabGlobal < MlabBase
  self.table_name = 'globals'
  self.primary_key = 'id'

  # Scope for non-retired records
  scope :not_retired, -> { where('globals.retired = 0 OR globals.retired IS NULL') }

  # Get the active global configuration
  def self.current
    not_retired.order(id: :desc).first
  end
end
