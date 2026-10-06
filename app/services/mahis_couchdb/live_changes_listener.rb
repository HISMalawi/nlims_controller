# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module MahisCouchdb
  # Permanent listener for CouchDB's continuous _changes feed.
  class LiveChangesListener
    include ActivityLogger

    attr_reader :client, :changes_service

    def initialize(client = Client.new, changes_service = nil)
      @client = client
      @changes_service = changes_service || OrderChangesService.new(client)
      @running = true
    end

    def start
      unless client.enabled?
        log_warn('[MaHIS CouchDB Listener] Disabled. Set mahis_couchdb.enabled=true to start listening.')
        return false
      end

      log_info("[MaHIS CouchDB Listener] Starting live listener for #{client.config.database}")
      log_info('[MaHIS CouchDB Listener] Processing pending NLiMS lab orders before live feed')
      changes_service.process_all_pending_documents if changes_service.respond_to?(:process_all_pending_documents)
      listen_forever
    end

    def stop
      request_stop
      log_info('[MaHIS CouchDB Listener] Stop requested')
    end

    def request_stop
      @running = false
    end

    private

    def listen_forever
      live_feed_started = false

      while @running
        begin
          if live_feed_started && changes_service.respond_to?(:process_all_pending_documents)
            log_info('[MaHIS CouchDB Listener] Catching up pending NLiMS lab orders before reconnecting')
            changes_service.process_all_pending_documents
          end

          live_feed_started = true
          listen_once
        rescue Interrupt
          request_stop
        rescue StandardError => e
          log_error("[MaHIS CouchDB Listener] Stream failed: #{e.class} - #{e.message}")
          sleep client.config.reconnect_delay if @running
        end
      end
    end

    def listen_once
      since = 'now'
      uri = URI(client.changes_feed_url(
                  since:,
                  feed: 'continuous',
                  include_docs: true,
                  heartbeat: client.config.heartbeat
                ))

      log_info("[MaHIS CouchDB Listener] Connecting to #{uri} from sequence #{since}")
      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == 'https',
        open_timeout: client.config.open_timeout,
        read_timeout: client.config.read_timeout
      ) do |http|
        request = Net::HTTP::Get.new(uri)
        request.basic_auth(client.config.username.to_s, client.config.password.to_s) if client.config.username || client.config.password

        http.request(request) do |response|
          raise "CouchDB _changes feed failed with HTTP #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

          consume_response(response)
        end
      end
    end

    def consume_response(response)
      buffer = +''

      response.read_body do |chunk|
        break unless @running

        buffer << chunk
        while (line = next_line!(buffer))
          process_line(line)
        end
      end
    end

    def next_line!(buffer)
      index = buffer.index("\n")
      return nil unless index

      buffer.slice!(0..index)
    end

    def process_line(line)
      line = line.to_s.strip
      return if line.blank?

      change = JSON.parse(line)
      imported = changes_service.process_change(change)
      log_info("[MaHIS CouchDB Listener] Processed change id=#{change['id']} seq=#{change['seq']} imported_orders=#{imported}")
    rescue JSON::ParserError => e
      log_warn("[MaHIS CouchDB Listener] Ignored malformed change line: #{e.message}")
    rescue StandardError => e
      log_error("[MaHIS CouchDB Listener] Failed to process change: #{e.class} - #{e.message}")
    end
  end
end
