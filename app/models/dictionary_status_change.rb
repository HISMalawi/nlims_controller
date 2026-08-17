# frozen_string_literal: true

# One row per publication transition of a dictionary entry.
class DictionaryStatusChange < ApplicationRecord
  scope :recent, -> { order(created_at: :desc) }
  scope :for_entity, ->(uuid) { where(entity_uuid: uuid).order(:created_at) }

  # The actor arrives with the entry rather than through ambient state: a rake
  # task passes the operator, the interface passes the signed-in user, an import
  # passes itself. Thread-local state looked tidier and silently recorded 934
  # promotions with no actor at all.
  def self.record!(entry, from:, actor: nil, reason: nil)
    create!(
      entity_type: entry.class.entity_type,
      entity_uuid: entry.uuid,
      national_code: entry.national_code,
      from_status: from,
      to_status: entry.status,
      revision: entry.revision,
      actor: actor,
      reason: reason,
      created_at: Time.current
    )
  end
end
