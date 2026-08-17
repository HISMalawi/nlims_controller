# frozen_string_literal: true

require "net/http"

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

    class TransportError < StandardError; end

    attr_reader :batches, :applier

    def self.from_env(**options)
      new(
        base_url: ENV.fetch("SISLAB_SYNC_NATIONAL_URL"),
        api_key: ENV.fetch("SISLAB_SYNC_NATIONAL_API_KEY"),
        **options
      )
    end

    def initialize(base_url: nil, api_key: nil, limit: Dictionary::DEFAULT_LIMIT, transport: nil)
      @transport = transport || HttpTransport.new(base_url: base_url, api_key: api_key)
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

    # Net::HTTP rather than a gem: one GET with a bearer token does not need one.
    class HttpTransport
      OPEN_TIMEOUT = 10
      READ_TIMEOUT = 60

      def initialize(base_url:, api_key:)
        raise TransportError, "SISLAB_SYNC_NATIONAL_URL is not set" if base_url.blank?
        raise TransportError, "SISLAB_SYNC_NATIONAL_API_KEY is not set" if api_key.blank?

        @base_uri = URI.parse(base_url)
        @api_key = api_key
      end

      def get(path, params = {})
        uri = @base_uri.dup
        uri.path = path
        uri.query = URI.encode_www_form(params)

        response = perform(uri)

        unless response.is_a?(Net::HTTPSuccess)
          raise TransportError, "#{uri} answered #{response.code}: #{response.body.to_s.truncate(200)}"
        end

        JSON.parse(response.body)
      rescue JSON::ParserError => e
        raise TransportError, "#{uri} did not answer with json: #{e.message}"
      end

      private

      def perform(uri)
        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = "Bearer #{@api_key}"
        request["Accept"] = "application/json"

        Net::HTTP.start(uri.hostname, uri.port,
                        use_ssl: uri.scheme == "https",
                        open_timeout: OPEN_TIMEOUT,
                        read_timeout: READ_TIMEOUT) do |http|
          http.request(request)
        end
      rescue SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, SocketError => e
        raise TransportError, "#{uri} unreachable: #{e.class}: #{e.message}"
      end
    end
  end
end
