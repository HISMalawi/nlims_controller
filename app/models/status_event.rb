# frozen_string_literal: true

# One row per transition, for orders and for the tests on them.
class StatusEvent < ApplicationRecord
  include HasUuid

  scope :for_entity, ->(uuid) { where(entity_uuid: uuid).order(:created_at, :id) }
  scope :for_order, ->(tracking_number) { where(tracking_number: tracking_number).order(:created_at, :id) }
  scope :recent, -> { order(created_at: :desc, id: :desc) }

  # The actor arrives with the record rather than through ambient state: the API
  # passes the client, the interface passes the signed-in user, a referral
  # passes the node it came from.
  def self.record!(record, from:, actor: nil, reason: nil)
    create!(
      entity_type: record.class.entity_type,
      entity_uuid: record.uuid,
      tracking_number: record.tracking_number,
      from_status: from,
      to_status: record.status,
      actor: actor,
      reason: reason,
      created_at: Time.current
    )
  end

  # Append-only, enforced rather than agreed: a history that can be edited
  # afterwards is not a history. Insert still works — a record being created is
  # not yet persisted.
  def readonly?
    persisted?
  end

  def destroy
    raise ActiveRecord::ReadOnlyRecord, "status events are append-only"
  end

  def created?
    from_status.nil?
  end
end
