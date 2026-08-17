# frozen_string_literal: true

# One row per transition, for orders and for the tests on them.
class StatusEvent < ApplicationRecord
  include HasUuid

  # The record this event is about, carried from the caller rather than looked
  # up again. It is not a column: it exists so the outbox can serialise the
  # subject without a second query, inside the same transaction.
  attr_accessor :subject

  after_create :publish_to_outbox

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
      created_at: Time.current,
      subject: record
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

  private

  # The history is already a complete record of every transition, so the outbox
  # is filled from it rather than from a dozen call sites that would each have
  # to remember. Written here, in the transaction that wrote the transition.
  def publish_to_outbox
    return if subject.nil?

    OutboxEvent.record!(
      type: outbox_type,
      aggregate_uuid: order_uuid,
      payload: outbox_payload,
      occurred_at: created_at
    )
  end

  # A rejection is reported as what it is. The status alone would say the sample
  # was refused without saying why, and the reason is the most useful thing the
  # laboratory ever tells the rest of the system.
  def outbox_type
    if entity_type == "orders"
      return OutboxEvent::SPECIMEN_REJECTED if to_status == Order::REJECTED
      return created? ? OutboxEvent::ORDER_CREATED : OutboxEvent::ORDER_STATUS_CHANGED
    end

    created? ? OutboxEvent::ORDER_TEST_ADDED : OutboxEvent::TEST_STATUS_CHANGED
  end

  # Everything about one sample travels under the order's uuid, tests included,
  # so the national node applies a sample's history in the order it happened.
  def order_uuid
    entity_type == "orders" ? entity_uuid : subject.order.uuid
  end

  def outbox_payload
    transition = {
      tracking_number: tracking_number,
      entity: entity_type,
      entity_uuid: entity_uuid,
      from_status: from_status,
      to_status: to_status,
      actor: actor,
      reason: reason
    }

    transition.merge(detail)
  end

  # A creation carries the whole record, because the national node may be seeing
  # this sample for the first time and cannot apply a status change to something
  # it has never heard of. Later events carry only what moved.
  def detail
    case outbox_type
    when OutboxEvent::ORDER_CREATED then { order: OrderSerializer.call(snapshot) }
    when OutboxEvent::ORDER_TEST_ADDED then { test: OrderTestSerializer.call(snapshot) }
    when OutboxEvent::SPECIMEN_REJECTED
      { rejection_reason: DictionaryReference.call(subject.rejection_reason) }
    else {}
    end
  end

  # A copy of the subject, loaded fresh. Serialising walks associations, and
  # doing that to the caller's own object would leave them loaded behind it — an
  # order serialised before its tests were added would go on answering that it
  # has none.
  def snapshot
    subject.class.find(subject.id)
  end
end
