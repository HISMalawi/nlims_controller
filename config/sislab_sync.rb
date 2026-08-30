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

    # The code this node is known by across the network. A local node is a
    # health facility and answers to its entry in the national register; the
    # national node is a single well-known code.
    def node_code
      @node_code ||= facility_code
    end

    # This node's health facility code — the one thing an installation has to be
    # told. It names an entry in the `facilities` register the national node
    # publishes, and everything else about this node is read from there.
    #
    # SISLAB_SYNC_NODE_CODE is still accepted: it has always meant "the code
    # this node answers to", and that is now the unit. SISLAB_SYNC_LAB_CODE is
    # refused rather than read, because it meant a laboratory, and a node
    # quietly calling itself by one would address its samples to a register
    # entry of the wrong kind.
    def facility_code
      @facility_code ||= fetch_facility_code
    end

    # This node's own entry in the register, or nil before the register has been
    # pulled. Not memoised: the register arrives over the feed like any other
    # dictionary entry, and a node that read it once at boot would go on calling
    # itself by a name the capital had already corrected.
    def facility
      return nil unless local?

      Facility.find_by(national_code: facility_code)
    rescue ActiveRecord::ActiveRecordError, NameError
      # Asked before the schema exists — during a migration, or on a node whose
      # database has not been created yet. The code alone is enough to boot.
      nil
    end

    # The laboratories inside this unit, as the register knows them. Includes the
    # ones this node registered itself and the capital has not named yet: they
    # are working laboratories, and the screens have to show them.
    def labs
      return Lab.none unless local?

      Lab.in_facility(facility_code).ordered
    rescue ActiveRecord::ActiveRecordError, NameError
      []
    end

    # What this node calls itself on a screen.
    def node_name
      facility&.name.presence || facility_code
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
      @mode = @node_code = @facility_code = @version = @tls_terminated = nil
    end

    private

    def fetch_facility_code
      code = ENV["SISLAB_SYNC_FACILITY_CODE"].presence || ENV["SISLAB_SYNC_NODE_CODE"].presence
      return code if code
      return "NATIONAL" if national?

      if ENV["SISLAB_SYNC_LAB_CODE"].present?
        raise InvalidMode,
              "SISLAB_SYNC_LAB_CODE names a laboratory; a node is a health facility. " \
              "Set SISLAB_SYNC_FACILITY_CODE to this unit's code."
      end

      raise InvalidMode, "SISLAB_SYNC_FACILITY_CODE is required in local mode"
    end

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
