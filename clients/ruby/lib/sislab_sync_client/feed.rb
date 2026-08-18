# frozen_string_literal: true

module SislabSyncClient
  # A cursor feed, walked to its end.
  #
  # Every feed on the node — results, the laboratory's work, the dictionary, a
  # node's inbound events — pages the same way: send `since`, read the records,
  # keep `meta.next_cursor`, and go again while `meta.has_more`. The cursor is a
  # revision from a locked counter and never a timestamp, so nothing can be
  # committed slowly enough to slip behind a cursor that has already passed it.
  #
  # `each_page` is the one to build on. A consumer that stores the cursor after
  # each page can be killed between pages and resume without either losing a
  # record or reading one twice; a consumer that stores it only at the end
  # cannot.
  class Feed
    include Enumerable

    attr_reader :cursor

    def initialize(connection, path, params = {}, since: 0, limit: nil)
      @connection = connection
      @path = path
      @params = params
      @cursor = since.to_i
      @limit = limit
    end

    # Yields each page and the cursor that page ends at. Answers the cursor it
    # finished on, which is what the caller stores.
    def each_page
      return enum_for(:each_page) unless block_given?

      loop do
        response = @connection.get(@path, @params.merge(since: @cursor, limit: @limit))
        records = Array(response.data)
        @cursor = advance(response)

        yield records, @cursor unless records.empty?
        break unless response.more?
      end

      @cursor
    end

    def each(&block)
      return enum_for(:each) unless block_given?

      each_page { |records, _| records.each(&block) }
      self
    end

    private

    # A node that says there is more but hands back the cursor it was given
    # would have this loop asking for the same page for ever. Better to stop
    # and say so than to spin against a laboratory's node.
    def advance(response)
      next_cursor = (response.cursor || @cursor).to_i
      return next_cursor unless response.more? && next_cursor <= @cursor

      raise FeedStalled.new(
        "#{@path} says there is more but its cursor did not move past #{@cursor}",
        status: response.status
      )
    end
  end
end
