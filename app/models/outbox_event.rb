# frozen_string_literal: true

# One thing that happened here and has to reach the national node.
#
# Rows are written by the records that change, inside their own transaction, and
# read by the push job. Nothing deletes them: a delivered row is the evidence it
# was sent, and a failed one has to stay in the queue where an operator can see
# it rather than disappearing into a log file.
class OutboxEvent < ApplicationRecord
  self.table_name = "sync_outbox"

  # `type` is the word the wire format uses, and the column is named after it.
  # Active Record would otherwise read it as single-table inheritance and try to
  # instantiate a class called "order.created".
  self.inheritance_column = nil

  PATIENT_UPSERTED = "patient.upserted"
  ORDER_CREATED = "order.created"
  ORDER_STATUS_CHANGED = "order.status_changed"
  ORDER_TEST_ADDED = "order.test_added"
  TEST_STATUS_CHANGED = "test.status_changed"
  TEST_RESULT_RECORDED = "test.result_recorded"
  SPECIMEN_REJECTED = "specimen.rejected"

  # S10 fills these in; the national node already has to know the words, since
  # a node running ahead of it will send them.
  REFERRAL_DISPATCHED = "referral.dispatched"
  REFERRAL_RECEIVED = "referral.received"
  REFERRAL_REJECTED = "referral.rejected"

  # A laboratory this node met for the first time on an arriving sample. Not a
  # clinical fact, but it travels the same road for the same reason: it was
  # written here, the capital has to have it, and the link to the capital is
  # down as often as it is up.
  LAB_REGISTERED = "lab.registered"

  TYPES = [
    PATIENT_UPSERTED, ORDER_CREATED, ORDER_STATUS_CHANGED, ORDER_TEST_ADDED,
    TEST_STATUS_CHANGED, TEST_RESULT_RECORDED, SPECIMEN_REJECTED,
    REFERRAL_DISPATCHED, REFERRAL_RECEIVED, REFERRAL_REJECTED, LAB_REGISTERED
  ].freeze

  # Two writers can read the same highest sequence for one aggregate and both
  # try to use it. The unique index refuses the second, and it takes the next
  # number instead — the same arrangement as the tracking number, and for the
  # same reason: the index is the guarantee, not the read.
  SEQUENCE_ATTEMPTS = 5

  serialize :payload, coder: JSON

  validates :event_uuid, :aggregate_uuid, :occurred_at, presence: true
  validates :type, inclusion: { in: TYPES }

  scope :pending, -> { where(delivered_at: nil) }
  scope :delivered, -> { where.not(delivered_at: nil) }
  scope :failing, -> { pending.where(attempts: 1..) }
  scope :in_order, -> { order(:aggregate_uuid, :sequence) }
  scope :oldest_first, -> { order(:id) }

  # Due now, oldest first. Ordering by id rather than by aggregate keeps the
  # batches in the order things actually happened, which is what a reader
  # following one sample wants to see.
  scope :ready, lambda { |now = Time.current|
    pending.where("next_attempt_at IS NULL OR next_attempt_at <= ?", now).oldest_first
  }

  class << self
    # Called from inside the transaction that made the change. A national node
    # writes nothing: it receives events, it does not produce them.
    def record!(type:, aggregate_uuid:, payload:, occurred_at: nil)
      return nil unless SislabSync.local?

      # Applying somebody else's event is not news of this node's own. Without
      # this, two nodes holding one referred sample would send each other's
      # events back and forth for ever.
      return nil if Current.replicating

      attempts = 0

      begin
        create!(
          event_uuid: SecureRandom.uuid,
          aggregate_uuid: aggregate_uuid,
          sequence: next_sequence_for(aggregate_uuid),
          type: type,
          payload: payload,
          occurred_at: occurred_at || Time.current
        )
      rescue ActiveRecord::RecordNotUnique
        attempts += 1
        retry if attempts < SEQUENCE_ATTEMPTS

        raise
      end
    end

    def next_sequence_for(aggregate_uuid)
      where(aggregate_uuid: aggregate_uuid).maximum(:sequence).to_i + 1
    end

    # How far behind this node is, which is the number an operator watches when
    # the link to the capital has been down.
    def backlog
      pending.count
    end
  end

  def delivered?
    delivered_at.present?
  end

  def mark_delivered!
    update!(delivered_at: Time.current, last_error: nil, next_attempt_at: nil)
  end

  # Exponential, capped, and jittered a little so that a hundred nodes coming
  # back after the same outage do not all retry in the same second.
  def mark_failed!(error, backoff: Backoff)
    tries = attempts + 1

    update!(
      attempts: tries,
      last_error: error.to_s.truncate(1000),
      next_attempt_at: backoff.next_attempt_at(tries)
    )
  end

  # Puts a failed event back at the front of the queue, for the operator who has
  # fixed whatever the national node was complaining about.
  def retry_now!
    update!(next_attempt_at: nil, last_error: nil)
  end

  def to_wire
    {
      event_uuid: event_uuid,
      aggregate_uuid: aggregate_uuid,
      sequence: sequence,
      type: type,
      occurred_at: occurred_at.iso8601,
      payload: payload
    }
  end

  # A link to a district laboratory is down for minutes or for days, and neither
  # should be answered with a retry every second.
  module Backoff
    BASE = 30.seconds
    MAX = 30.minutes

    def self.next_attempt_at(attempts, now: Time.current)
      delay = [ BASE * (2**[ attempts - 1, 10 ].min), MAX ].min
      now + delay + rand(0..(delay.to_i / 4))
    end
  end
end
