# frozen_string_literal: true

# Run mode for this node.
#
# The same image runs everywhere; SISLAB_SYNC_MODE decides what it is. A local
# node serves the EMR and the SISLAB, generates tracking numbers and pushes its
# outbox upwards. A national node owns the dictionary, receives events and
# routes referrals. Nothing else in the codebase should read the env var.
#
# Loaded from config/application.rb before the Application class, so the mode is
# available to initializers and to the route file.
module SislabSync
  MODES = %w[local national].freeze

  class InvalidMode < StandardError; end

  class << self
    def mode
      @mode ||= fetch_mode
    end

    def local?
      mode == "local"
    end

    def national?
      mode == "national"
    end

    # The code this node is known by across the network. A local node uses its
    # facility code; the national node is a single well-known code.
    def node_code
      @node_code ||= ENV.fetch("SISLAB_SYNC_NODE_CODE") do
        national? ? "NATIONAL" : raise(InvalidMode, "SISLAB_SYNC_NODE_CODE is required in local mode")
      end
    end

    def version
      @version ||= File.read(Rails.root.join("VERSION")).strip
    rescue Errno::ENOENT
      "0.0.0-dev"
    end

    # Whether a reverse proxy in front of this node terminates TLS. True by
    # default: that is how a node is meant to be deployed, and production.rb
    # turns on force_ssl and assume_ssl on the strength of it.
    #
    # A node reached over plain HTTP has to say so. Left at the default it would
    # tell Rails every request arrived over TLS when none did, and the node would
    # mark its session cookie Secure (never sent back, so nobody stays signed in)
    # and advertise itself as https in the URLs it builds — the FHIR Bundle links
    # included, which sends clients back at a port that speaks no TLS.
    def tls_terminated?
      return @tls_terminated unless @tls_terminated.nil?

      @tls_terminated = ENV.fetch("SISLAB_SYNC_TLS_TERMINATED", "true").strip.downcase != "false"
    end

    # Test support: forget everything memoised from the environment.
    def reset!
      @mode = @node_code = @version = @tls_terminated = nil
    end

    private

    def fetch_mode
      value = ENV.fetch("SISLAB_SYNC_MODE", nil)
      raise InvalidMode, "SISLAB_SYNC_MODE is not set (expected one of: #{MODES.join(', ')})" if value.blank?

      value = value.strip.downcase
      unless MODES.include?(value)
        raise InvalidMode, "SISLAB_SYNC_MODE=#{value.inspect} is not a valid mode (expected one of: #{MODES.join(', ')})"
      end

      value
    end
  end
end
