# frozen_string_literal: true

module Sync
  # A batch of events from one node, stored and then applied in order.
  #
  # Storing comes first and is idempotent by event_uuid: delivery is
  # at-least-once, so the same batch arriving twice — because the answer was
  # lost rather than the request — has to be recognised rather than duplicated.
  #
  # Applying comes second, and only in sequence. An event whose predecessor has
  # not arrived waits where it is; applying it anyway would mean recording a
  # result against a sample this node has not been told about, or a status
  # change whose order is a guess.
  class Ingest
    REQUIRED = %w[event_uuid aggregate_uuid sequence type occurred_at].freeze

    Result = Struct.new(:accepted, :rejected, keyword_init: true) do
      def as_json
        { accepted: accepted, rejected: rejected }
      end
    end

    def initialize(node_code:, events:)
      @node_code = node_code.to_s
      @events = Array(events).map { |event| event.to_h.stringify_keys }
      @accepted = []
      @rejected = []
    end

    def call
      streams = @events.filter_map { |event| store(event) }.uniq

      streams.each { |aggregate_uuid| drain(aggregate_uuid) }

      Result.new(accepted: @accepted, rejected: @rejected)
    end

    private

    # Returns the aggregate whose stream now has something to drain, or nil if
    # there is nothing to do for this event.
    def store(event)
      missing = REQUIRED.select { |key| event[key].blank? }
      return refuse(event["event_uuid"], Rejected::MALFORMED, "faltam campos: #{missing.join(', ')}") if missing.any?

      existing = InboundEvent.find_by(event_uuid: event["event_uuid"])
      return remember(existing) if existing

      record = InboundEvent.create!(
        event_uuid: event["event_uuid"],
        node_code: @node_code,
        aggregate_uuid: event["aggregate_uuid"],
        sequence: event["sequence"],
        type: event["type"],
        payload: event["payload"] || {},
        occurred_at: event["occurred_at"],
        received_at: Time.current,
        status: InboundEvent::PENDING
      )

      @accepted << record.event_uuid
      record.aggregate_uuid
    rescue ActiveRecord::RecordNotUnique
      # Two copies of the batch arrived at once. Whichever lost the race is
      # looking at the row the winner wrote, which is the answer it wanted.
      remember(InboundEvent.find_by!(event_uuid: event["event_uuid"]))
    end

    # An event already held is accepted again — that is what idempotent means —
    # but a rejected one is reported as rejected, so a sender that resends does
    # not read silence as success.
    def remember(existing)
      if existing.status == InboundEvent::REJECTED
        @rejected << { event_uuid: existing.event_uuid, code: existing.error_code, message: existing.error_message }
        return nil
      end

      @accepted << existing.event_uuid
      existing.pending? ? existing.aggregate_uuid : nil
    end

    def refuse(event_uuid, code, message)
      @rejected << { event_uuid: event_uuid, code: code, message: message }
      nil
    end

    # Applies what can be applied, in sequence, and stops at the first gap — or
    # at a rejection, which blocks its own stream on purpose. One sample stuck
    # waiting for an administrator must not hold up any other.
    def drain(aggregate_uuid)
      loop do
        expected = InboundEvent.last_applied_sequence(@node_code, aggregate_uuid) + 1
        event = InboundEvent.stream(@node_code, aggregate_uuid).pending.find_by(sequence: expected)

        break if event.nil?
        break unless apply(event)
      end
    end

    def apply(event)
      InboundEvent.transaction do
        Applier.new(event).apply!
        event.mark_applied!
      end

      true
    rescue Rejected => e
      reject(event, e.code, e.message)
    rescue ActiveRecord::RecordInvalid => e
      reject(event, Rejected::INVALID, e.record.errors.full_messages.to_sentence)
    rescue StandardError => e
      # Kept rather than lost. A bug on this side must not swallow a laboratory's
      # result: the event stays, visible and retryable, with what went wrong.
      reject(event, Rejected::APPLY_FAILED, "#{e.class}: #{e.message}")
    end

    def reject(event, code, message)
      event.mark_rejected!(code, message)
      @accepted.delete(event.event_uuid)
      @rejected << { event_uuid: event.event_uuid, code: code, message: message }

      false
    end
  end
end
