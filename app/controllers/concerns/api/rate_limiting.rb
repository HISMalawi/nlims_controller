# frozen_string_literal: true

module Api
  # A fixed window per key. The point is not to shape traffic finely, it is to
  # stop one misconfigured client — an EMR polling results in a tight loop — from
  # starving a laboratory's node.
  module RateLimiting
    extend ActiveSupport::Concern

    WINDOW = 60
    DEFAULT_LIMIT = 600

    included do
      before_action :enforce_rate_limit!
    end

    private

    def enforce_rate_limit!
      return true unless Current.api_key

      limit = rate_limit
      count = Rails.cache.increment(rate_limit_cache_key, 1, expires_in: WINDOW.seconds).to_i
      return true if count <= limit

      response.headers["Retry-After"] = seconds_until_window_ends.to_s
      render_api_error(Errors::RATE_LIMITED)
      false
    end

    def rate_limit
      ENV.fetch("API_RATE_LIMIT_PER_MINUTE", DEFAULT_LIMIT).to_i
    end

    # Bucketed by wall clock so the counter expires on its own and no sweeper
    # is needed.
    def rate_limit_cache_key
      "api:rate_limit:#{Current.api_key.id}:#{Time.current.to_i / WINDOW}"
    end

    def seconds_until_window_ends
      WINDOW - (Time.current.to_i % WINDOW)
    end
  end
end
