# frozen_string_literal: true

module Dictionary
  # Pulls the dictionary from the national node onto this one.
  #
  # The local node always initiates: laboratories sit behind NAT with no fixed
  # address, so the national node could not reach them if it wanted to.
  #
  # The cursor advances only after a batch has been committed. A crash between
  # the two costs one re-read, which is harmless because entries are matched by
  # uuid — the alternative, advancing first, would lose the batch for good.
  class Puller
    # A stop, not a limit: 200 batches of 500 is far more than the dictionary
    # holds, so hitting it means the feed is not draining and the run should end
    # and be looked at rather than spin.
    MAX_BATCHES = 200

    # The transport moved to NodeTransport when the outbox push needed the same
    # thing in the other direction. Kept as a name here because a broken feed is
    # something callers of the puller already rescue by this one.
    TransportError = NodeTransport::TransportError

    attr_reader :batches, :applier

    def self.from_env(**options)
      new(transport: NodeTransport.from_env, **options)
    end

    def initialize(base_url: nil, api_key: nil, limit: Dictionary::DEFAULT_LIMIT, transport: nil)
      @transport = transport || NodeTransport.new(base_url: base_url, api_key: api_key)
      @limit = limit
      @batches = 0
      @applier = Applier.new
    end

    def call
      cursor = SyncCursor.for(SyncCursor::DICTIONARY)
      cursor.touch_attempt!

      while @batches < MAX_BATCHES
        response = @transport.get("/api/v3/dictionary/changes", since: cursor.value, limit: @limit)
        entries = Array(response["data"])
        meta = response["meta"] || {}

        break if entries.empty?

        @applier.apply(entries)
        cursor.advance!(meta["next_cursor"])
        @batches += 1

        break unless meta["has_more"]
      end

      cursor.advance!(cursor.value) # stamps last_synced_at even when nothing moved
      self
    rescue StandardError => e
      SyncCursor.for(SyncCursor::DICTIONARY).record_failure!("#{e.class}: #{e.message}")
      raise
    end

    def summary
      parts = @applier.applied.sort.map { |entity_type, count| "#{entity_type}=#{count}" }
      parts << "deferred=#{@applier.deferred}" if @applier.deferred.positive?
      parts << "resolved=#{@applier.resolved}" if @applier.resolved.positive?
      parts << "batches=#{@batches}"
      parts.join(" ")
    end
  end
end
