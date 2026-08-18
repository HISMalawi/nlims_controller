# frozen_string_literal: true

require "json"
require "securerandom"

module SislabSyncClient
  # One key pointed at one node, and the three things every call has to get
  # right: the envelope, the refusals, and when it is safe to try again.
  #
  # Every endpoint answers `{ data, meta, errors }`, including the failures. So
  # unwrapping happens once, here, and a caller never sees the envelope — it
  # gets the data, or an exception carrying the node's own error code.
  class Connection
    MAX_ATTEMPTS = 3

    # A ceiling on what a node can talk this client into waiting. Honouring
    # Retry-After matters; sleeping for an hour because a header said so does
    # not.
    MAX_RETRY_AFTER = 60

    attr_reader :base_url

    def initialize(base_url:, api_key:, transport: nil, max_attempts: MAX_ATTEMPTS, sleeper: nil)
      raise ArgumentError, "base_url is required" if base_url.to_s.empty?
      raise ArgumentError, "api_key is required" if api_key.to_s.empty?

      @base_url = base_url
      @api_key = api_key
      @transport = transport || Transport.new(base_url: base_url)
      @max_attempts = max_attempts
      @sleeper = sleeper || ->(seconds) { sleep(seconds) }
    end

    def get(path, params = {})
      request(method: :get, path: path, params: compact(params))
    end

    # `idempotency_key` is what makes a retry safe. The node stores the first
    # answer against it and replays that answer rather than doing the work
    # twice, so a request that carries one can be retried after a dropped
    # connection without wondering whether it landed.
    def post(path, body = nil, idempotency_key: nil)
      request(method: :post, path: path, body: body, idempotency_key: idempotency_key)
    end

    def patch(path, body = nil)
      request(method: :patch, path: path, body: body)
    end

    private

    def request(method:, path:, params: {}, body: nil, idempotency_key: nil)
      headers = { "Accept" => "application/json", "Authorization" => "Bearer #{@api_key}" }
      headers["Idempotency-Key"] = idempotency_key if idempotency_key

      attempt = 0

      begin
        attempt += 1
        status, response_headers, payload = @transport.call(
          method: method, path: path, params: params, body: body, headers: headers
        )

        interpret(status, response_headers, payload)
      rescue RateLimited => e
        raise e if attempt >= @max_attempts

        @sleeper.call(retry_delay(e.retry_after, attempt))
        retry
      rescue TransportError
        # Only where trying again cannot do the work twice: a read, or a write
        # the node will recognise as one it has already answered.
        raise unless retryable?(method, idempotency_key)
        raise if attempt >= @max_attempts

        @sleeper.call(2**(attempt - 1))
        retry
      end
    end

    def retryable?(method, idempotency_key)
      method == :get || !idempotency_key.nil?
    end

    def retry_delay(retry_after, attempt)
      seconds = retry_after.to_i
      seconds = 2**(attempt - 1) if seconds <= 0

      [ seconds, MAX_RETRY_AFTER ].min
    end

    def interpret(status, headers, payload)
      body = parse(status, payload)

      return Response.new(data: body["data"], meta: body["meta"] || {}, status: status) if status.between?(200, 299)

      raise error_from(status, headers, body)
    end

    def parse(status, payload)
      body = JSON.parse(payload.to_s)
      raise UnexpectedResponse.new("the node answered #{status} with #{payload.class}", status: status) unless
        body.is_a?(Hash)

      body
    rescue JSON::ParserError
      raise UnexpectedResponse.new(
        "the node answered #{status} with something that is not json: #{payload.to_s[0, 200]}",
        status: status
      )
    end

    def error_from(status, headers, body)
      error = Array(body["errors"]).first || {}
      code = error["code"]
      message = error["message"] || "the node answered #{status}"
      options = { code: code, field: error["field"], status: status, body: body }

      return RateLimited.new(message, retry_after: retry_after_of(headers), **options) if code == "rate_limited"

      SislabSyncClient.error_for(code).new(message, **options)
    end

    def retry_after_of(headers)
      headers.to_h.find { |name, _| name.to_s.casecmp?("retry-after") }&.last
    end

    def compact(params)
      (params || {}).reject { |_, value| value.nil? || value == "" }
    end
  end

  # What a call gives back: the data, and the meta a feed needs to page.
  Response = Struct.new(:data, :meta, :status, keyword_init: true) do
    def cursor = meta["next_cursor"]
    def more? = meta["has_more"] == true
  end
end
