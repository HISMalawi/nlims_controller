# frozen_string_literal: true

# One transition on the wire.
class StatusEventSerializer
  def self.call(event)
    {
      uuid: event.uuid,
      entity: event.entity_type,
      entity_uuid: event.entity_uuid,
      tracking_number: event.tracking_number,
      from_status: event.from_status,
      to_status: event.to_status,
      actor: event.actor,
      reason: event.reason,
      created_at: event.created_at&.iso8601
    }
  end
end
