# frozen_string_literal: true

module Sync
  # Sends the outbox to the national node, oldest first.
  #
  # Delivery is at-least-once: an answer that never arrives is indistinguishable
  # from a batch that never landed, so the same events go again and the national
  # node recognises them. That is why nothing here tries to be clever about
  # partial failures — resending is always safe.
  #
  # Order takes care of itself. An event that failed sits out its backoff while
  # later events for the same sample go on ahead; the national node holds those
  # as pending until the gap fills, which is exactly what it is built to do.
  class Push
    DEFAULT_BATCH = 100

    # A stop, not a limit. Hitting it means the queue is not draining and the
    # run should end and be looked at rather than spin.
    MAX_BATCHES = 50

    attr_reader :delivered, :failed, :batches

    def self.from_env(**options)
      new(transport: NodeTransport.from_env, **options)
    end

    def initialize(transport:, node_code: nil, batch_size: nil)
      @transport = transport
      @node_code = node_code || SislabSync.node_code
      @batch_size = (batch_size || ENV.fetch("SISLAB_SYNC_PUSH_BATCH", DEFAULT_BATCH)).to_i
      @delivered = 0
      @failed = 0
      @batches = 0
    end

    def call
      while @batches < MAX_BATCHES
        events = OutboxEvent.ready.limit(@batch_size).to_a
        break if events.empty?

        send_batch(events)
        @batches += 1
      end

      self
    end

    def summary
      "delivered=#{@delivered} failed=#{@failed} batches=#{@batches} pending=#{OutboxEvent.backlog}"
    end

    private

    def send_batch(events)
      response = @transport.post("/api/v3/sync/events",
                                 node_code: @node_code,
                                 events: events.map(&:to_wire))

      settle(events, response)
    rescue NodeTransport::TransportError => e
      # The link is down or the far end is unwell. Every event in the batch
      # waits, and the backoff grows, so a node that has been cut off for a day
      # is not still retrying every second when it comes back.
      events.each { |event| event.mark_failed!(e.message) }
      @failed += events.length

      raise
    end

    def settle(events, response)
      data = response["data"] || {}
      accepted = Array(data["accepted"]).to_set
      rejected = Array(data["rejected"]).index_by { |row| row["event_uuid"] }

      events.each do |event|
        if accepted.include?(event.event_uuid)
          event.mark_delivered!
          @delivered += 1
        else
          refusal = rejected[event.event_uuid]
          event.mark_failed!(refusal ? "#{refusal['code']}: #{refusal['message']}" : "no answer for this event")
          @failed += 1
        end
      end
    end
  end
end
