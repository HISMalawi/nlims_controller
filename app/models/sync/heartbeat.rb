# frozen_string_literal: true

module Sync
  # What this node reports about itself, whether or not it had anything to push.
  #
  # Sent even when the outbox is empty: an idle node and an unreachable one look
  # identical from the capital otherwise, and telling them apart is the point.
  class Heartbeat
    def self.from_env(**options)
      new(transport: NodeTransport.from_env, **options)
    end

    def initialize(transport:, node_code: nil)
      @transport = transport
      @node_code = node_code || SislabSync.node_code
    end

    # The answer is recorded as well as sent. Without it a local node has no way
    # of telling an operator when it last reached the capital: the outbox only
    # shows the time of the last delivery, and a node with nothing to say
    # delivers nothing for hours at a time while remaining perfectly healthy.
    def call
      response = @transport.post("/api/v3/nodes/heartbeat", payload)
      cursor.mark_synced!
      response
    rescue NodeTransport::TransportError => e
      cursor.record_failure!(e.message)
      raise
    end

    def payload
      cursor = SyncCursor.for(SyncCursor::DICTIONARY)

      {
        node_code: @node_code,
        version: SislabSync.version,
        dictionary_cursor: cursor.value,
        outbox_pending: OutboxEvent.pending.count,
        outbox_failing: OutboxEvent.failing.count,
        last_error: worst_error(cursor)
      }
    end

    private

    def cursor
      SyncCursor.for(SyncCursor::HEARTBEAT)
    end

    # Whichever of the two things that can be wrong went wrong most recently:
    # the dictionary is not coming down, or the outbox is not going up.
    def worst_error(cursor)
      OutboxEvent.failing.order(updated_at: :desc).pick(:last_error) || cursor.last_error
    end
  end
end
