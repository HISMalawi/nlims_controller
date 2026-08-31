# frozen_string_literal: true

module Sync
  # Collects what the national node is holding for this one: samples referred
  # here, and results produced elsewhere on samples this node sent away.
  #
  # The events are stored and applied by exactly the same machinery the national
  # node uses to receive them, so ordering, gaps and duplicates behave the same
  # way in both directions rather than in two ways that have to be kept in step.
  class Pull
    MAX_BATCHES = 50
    DEFAULT_LIMIT = 100

    attr_reader :applied, :rejected, :batches

    def self.from_env(**options)
      new(transport: NodeTransport.from_env, **options)
    end

    def initialize(transport:, node_code: nil, limit: DEFAULT_LIMIT)
      @transport = transport
      @node_code = node_code || SislabSync.node_code
      @limit = limit
      @applied = 0
      @rejected = 0
      @batches = 0
    end

    def call
      cursor = SyncCursor.for(SyncCursor::INBOUND)
      cursor.touch_attempt!

      while @batches < MAX_BATCHES
        response = @transport.get("/api/v3/sync/inbound", node_code: @node_code, since: cursor.value, limit: @limit)
        events = Array(response["data"])
        meta = response["meta"] || {}

        break if events.empty?

        ingest(events)

        # Advanced only after the batch is applied and committed. A crash
        # between the two costs a re-read, which is free: every event is
        # recognised by its uuid on the way in.
        cursor.advance!(meta["next_cursor"])
        @batches += 1

        break unless meta["has_more"]
      end

      cursor.advance!(cursor.value)
      self
    rescue StandardError => e
      SyncCursor.for(SyncCursor::INBOUND).record_failure!("#{e.class}: #{e.message}")
      raise
    end

    def summary
      "applied=#{@applied} rejected=#{@rejected} batches=#{@batches}"
    end

    private

    # Grouped by where each event came from. Two origins number their events
    # independently, so their streams have to be kept apart or one node's
    # sequence 2 would look like a gap in the other's.
    def ingest(events)
      replicating do
        events.group_by { |event| event["node_code"] }.each do |origin, batch|
          result = Ingest.new(node_code: origin, events: batch, sequenced: false).call

          @applied += result.accepted.length
          @rejected += result.rejected.length
        end
      end
    end

    # Nothing applied here is this node's own news, so none of it goes into the
    # outbox. Without this the two nodes holding a referred sample would send
    # each other the same events round in a circle.
    def replicating
      previous = Current.replicating
      Current.replicating = true
      yield
    ensure
      Current.replicating = previous
    end
  end
end
