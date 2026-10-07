# frozen_string_literal: true

module IntegrationStatus
  # Talks to one central EMR instance (MaHIS). Health, version and the auth token are fetched once
  # per client and shared by every site on that instance, so a run costs one health check and one
  # login per instance plus one order-summary call per site. Safe to share across threads.
  class EmrInstanceClient
    class AuthenticationError < StandardError; end

    attr_reader :instance

    def initialize(instance)
      @instance = instance
      @mutex = Mutex.new
      @cache = {}
    end

    # reachable: the server answered over HTTP; up: the app reports itself healthy
    def health
      memoize(:health) do
        body = get(instance.health_path)
        { reachable: true, up: body['status'].to_s.casecmp?('up'), error: body['error'] }
      rescue RestClient::Exceptions::Timeout => e
        { reachable: false, up: false, error: "Timeout: #{e.message}" }
      rescue RestClient::ExceptionWithResponse => e
        { reachable: true, up: false, error: "HTTP #{e.http_code}" }
      rescue StandardError => e
        { reachable: false, up: false, error: e.message }
      end
    end

    def version
      memoize(:version) do
        next 'N/A' if instance.version_path.blank?

        body = get(instance.version_path)
        (body['System version'] || body['version']).presence || 'N/A'
      rescue StandardError
        'N/A'
      end
    end

    # Returns the same `emr` hash shape the local NLIMS /orders_summary endpoint returns.
    # `ok` is false when the numbers could not be fetched, and `remark` says why.
    def order_summary(location_id:, start_date:, end_date:, concept_id:)
      return emr_error('MaHIS location not configured for site') if location_id.blank?
      return emr_error('MaHIS Not Reachable') unless health[:reachable]

      body = with_token_retry do |token|
        get(instance.summary_path,
            params: { start_date:, end_date:, concept_id:, location_id:, include_data: false },
            headers: { Authorization: "Bearer #{token}" })
      end
      count = body['count'].to_i
      {
        count:,
        last_order_date: body['last_order_date'],
        lab_orders: [],
        remark: count.zero? ? 'No orders drawn in EMR' : 'Orders drawn in EMR',
        ok: true
      }
    rescue AuthenticationError => e
      emr_error("MaHIS Authentication Failed - #{e.message}")
    rescue RestClient::Exceptions::Timeout
      emr_error('MaHIS Not Reachable - request timed out')
    rescue RestClient::ExceptionWithResponse => e
      if e.http_code == 404
        emr_error('URL for Order Summary not available in MaHIS')
      else
        emr_error("Error Fetching MaHIS Orders Summary - HTTP #{e.http_code}")
      end
    rescue StandardError => e
      emr_error("Error Fetching MaHIS Orders Summary - #{e.message}")
    end

    # Used by the "Test connection" button: checks health and that the credentials work.
    def test_connection
      result = { health:, version: }
      begin
        token
        result[:authenticated] = true
      rescue StandardError => e
        result[:authenticated] = false
        result[:auth_error] = e.message
      end
      result
    end

    private

    def with_token_retry
      yield token
    rescue RestClient::Unauthorized
      # Token expired or bound to a different IP; log in again once
      @mutex.synchronize { @cache.delete(:token) }
      yield token
    end

    # Failed logins are cached too, so bad credentials cost one request per run, not one per site
    def token
      result = memoize(:token) do
        { token: login }
      rescue StandardError => e
        { error: e }
      end
      raise result[:error] if result[:error]

      result[:token]
    end

    def login
      if instance.username.blank? || instance.password.blank?
        raise AuthenticationError, 'username/password not configured'
      end

      body = Http.request_json(
        method: :post,
        url: instance.url_for(instance.login_path),
        payload: { username: instance.username, password: instance.password },
        timeout: instance.timeout_seconds,
        verify_ssl: instance.verify_ssl
      )
      body['auth_token'].presence || raise(AuthenticationError, body['message'] || 'no token returned')
    rescue RestClient::Unauthorized
      raise AuthenticationError, 'invalid credentials'
    rescue RestClient::Exceptions::Timeout
      raise AuthenticationError, 'login request timed out'
    rescue RestClient::ExceptionWithResponse => e
      raise AuthenticationError, login_failure_message(e)
    end

    # The lab engine crashes (HTTP 500) instead of returning 401 when the account is unknown or is a
    # regular EMR user: lab logins only accept accounts created through POST /api/v1/lab/users.
    def login_failure_message(error)
      return "login failed - HTTP #{error.http_code}" unless error.http_code == 500

      "login failed - HTTP 500. Check that '#{instance.username}' is a lab API user created with " \
        "POST #{instance.url_for('/api/v1/lab/users')}; regular EMR accounts can't use the lab login"
    end

    def get(path, params: {}, headers: {})
      url = instance.url_for(path)
      url = "#{url}?#{params.to_query}" if params.present?
      Http.request_json(method: :get, url:, headers:,
                        timeout: instance.timeout_seconds, verify_ssl: instance.verify_ssl)
    end

    def emr_error(remark)
      { count: 0, last_order_date: nil, lab_orders: [], remark:, ok: false }
    end

    # Cache per client. The lock is held while computing so concurrent site checks wait for the
    # single health/version/login request instead of all firing their own. Blocks must not call memoize.
    def memoize(key)
      @mutex.synchronize do
        return @cache[key] if @cache.key?(key)

        @cache[key] = yield
      end
    end
  end
end
