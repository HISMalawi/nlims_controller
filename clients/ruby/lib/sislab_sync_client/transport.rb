# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module SislabSyncClient
  # The wire. Net::HTTP and nothing else: a bearer token, a GET and a POST do
  # not need a dependency, and a laboratory server that cannot reach rubygems
  # can still install this.
  #
  # Kept separate from Connection so it can be replaced. The node's own test
  # suite drives this library against a real node without opening a socket by
  # passing a transport of its own — anything answering `call` with
  # `[status, headers, body]` will do.
  class Transport
    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 60

    REQUESTS = {
      get: Net::HTTP::Get,
      post: Net::HTTP::Post,
      patch: Net::HTTP::Patch,
      put: Net::HTTP::Put,
      delete: Net::HTTP::Delete
    }.freeze

    def initialize(base_url:, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT)
      @base_uri = URI.parse(base_url.to_s)
      @open_timeout = open_timeout
      @read_timeout = read_timeout
    end

    # Answers `[status, headers, body]` and raises TransportError only for the
    # things that mean the request never landed. An HTTP status the node chose
    # is an answer, not a failure, and is read further up.
    def call(method:, path:, params: {}, body: nil, headers: {})
      uri = uri_for(path, params)
      request = build(method, uri, body, headers)

      response = perform(request, uri)
      [ response.code.to_i, response.to_hash.transform_values(&:first), response.body ]
    end

    private

    def uri_for(path, params)
      uri = @base_uri.dup
      uri.path = path
      uri.query = URI.encode_www_form(params) if params && !params.empty?
      uri
    end

    def build(method, uri, body, headers)
      klass = REQUESTS.fetch(method) { raise TransportError, "#{method} is not a method this client sends" }
      request = klass.new(uri)
      headers.each { |name, value| request[name] = value }

      if body
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(body)
      end

      request
    end

    def perform(request, uri)
      Net::HTTP.start(uri.hostname, uri.port,
                      use_ssl: uri.scheme == "https",
                      open_timeout: @open_timeout,
                      read_timeout: @read_timeout) do |http|
        http.request(request)
      end
    rescue SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, SocketError, IOError => e
      raise TransportError.new("#{uri} unreachable: #{e.class}: #{e.message}")
    end
  end
end
