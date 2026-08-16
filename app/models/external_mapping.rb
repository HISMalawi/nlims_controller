# frozen_string_literal: true

# One client system's own code for a dictionary entry. Lets a SISLAB or an EMR
# keep the codes it already uses without those codes becoming national facts.
#
# Replaces the old name_mappings table, which mapped text to text and had no
# idea which system the text came from.
class ExternalMapping < ApplicationRecord
  SYSTEMS = %w[mlab emr iblis].freeze

  belongs_to :api_client, optional: true

  validates :system, presence: true, inclusion: { in: SYSTEMS }
  validates :entity_type, presence: true
  validates :entity_uuid, presence: true
  validates :external_code, presence: true
  validates :external_code, uniqueness: { scope: %i[system api_client_id entity_type] }

  scope :for_system, ->(system) { where(system: system) }

  # The dictionary record this mapping points at, whatever kind it is.
  def entity
    Dictionary.model_for(entity_type)&.find_by(uuid: entity_uuid)
  end

  # Translate a client's code into the national uuid. A mapping registered for a
  # specific client wins over one registered for the whole system.
  def self.resolve(system:, entity_type:, external_code:, api_client: nil)
    scope = where(system: system, entity_type: entity_type, external_code: external_code)
    scope.find_by(api_client: api_client)&.entity_uuid || scope.find_by(api_client: nil)&.entity_uuid
  end
end
