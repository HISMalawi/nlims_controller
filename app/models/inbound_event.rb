# frozen_string_literal: true

# One event a node has sent to the national one.
class InboundEvent < ApplicationRecord
  # As in the outbox: `type` is the word the wire format uses, and Active Record
  # would otherwise read the column as single-table inheritance.
  self.inheritance_column = nil

  PENDING = "pending"
  APPLIED = "applied"
  REJECTED = "rejected"

  serialize :payload, coder: JSON

  validates :event_uuid, :node_code, :aggregate_uuid, :sequence, :type, :occurred_at, presence: true

  scope :pending, -> { where(status: PENDING) }
  scope :applied, -> { where(status: APPLIED) }
  scope :rejected, -> { where(status: REJECTED) }
  scope :in_order, -> { order(:sequence, :id) }

  # One node's events about one sample. Two nodes can hold the same order — that
  # is what a referral is — and each numbers its own stream, so the stream is
  # identified by both.
  scope :stream, ->(node_code, aggregate_uuid) { where(node_code: node_code, aggregate_uuid: aggregate_uuid) }

  def self.last_applied_sequence(node_code, aggregate_uuid)
    stream(node_code, aggregate_uuid).applied.maximum(:sequence).to_i
  end

  # What is waiting for an event that has not arrived. An operator watching the
  # sync queue wants this list: it is the one that does not drain on its own.
  def self.stalled(older_than: 1.hour.ago)
    pending.where(received_at: ...older_than)
  end

  def pending?
    status == PENDING
  end

  def applied?
    status == APPLIED
  end

  def mark_applied!
    update!(status: APPLIED, applied_at: Time.current, error_code: nil, error_message: nil)
  end

  # Kept rather than deleted, and kept visible. An event the national node could
  # not make sense of is a conversation between two administrators, not a line
  # in a log nobody reads.
  def mark_rejected!(code, message)
    update!(status: REJECTED, error_code: code, error_message: message.to_s.truncate(1000))
  end
end
