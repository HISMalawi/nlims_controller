# frozen_string_literal: true

module SislabSyncClient
  # What every profile can do, because every node answers it.
  #
  # The three profiles below are not three clients. They are the same envelope,
  # the same cursors and the same refusals, split by which set of endpoints a
  # key is allowed to call — so that a team integrating an EMR reads only the
  # EMR's methods and cannot reach for the laboratory's by accident.
  class Profile
    DICTIONARY_ENTITIES = %w[
      labs departments specimen_types drugs organisms indicators test_types test_panels rejection_reasons
    ].freeze

    attr_reader :connection

    def initialize(base_url: nil, api_key: nil, connection: nil, **options)
      @connection = connection || Connection.new(base_url: base_url, api_key: api_key, **options)
    end

    # Which node this is, and what version it runs. The only call that needs no
    # key, and the first one to make when something does not work.
    def health
      connection.get("/api/v3/health").data
    end

    # What this key is and what it may do. The fastest way to tell a wrong key
    # from a wrong scope from a wrong node.
    def me
      connection.get("/api/v3/me").data
    end

    # The catalogue as it stands, for building a form. Active entries only.
    def dictionary(entity_type, since: 0, limit: nil)
      check_entity!(entity_type)

      connection.get("/api/v3/dictionary/#{entity_type}", since: since, limit: limit).data
    end

    # Everything that has changed across the whole dictionary, on one cursor.
    # The entries live in separate tables but share a single revision sequence,
    # which is what lets a client follow all of them with one number.
    def dictionary_changes(since: 0, entities: nil, limit: nil)
      entities = Array(entities)
      entities.each { |entity| check_entity!(entity) }
      params = entities.empty? ? {} : { entities: entities.join(",") }

      Feed.new(connection, "/api/v3/dictionary/changes", params, since: since, limit: limit)
    end

    private

    # Caught here rather than at the node, so a misspelling costs a method call
    # and not a round trip to a laboratory over a bad line.
    def check_entity!(entity_type)
      return if DICTIONARY_ENTITIES.include?(entity_type.to_s)

      raise ArgumentError,
            "#{entity_type} is not a dictionary entity; expected one of #{DICTIONARY_ENTITIES.join(', ')}"
    end

    # Tracking numbers and uuids are tame, but a path segment built by
    # concatenation is a habit worth not having.
    def escape(value)
      ERB::Util.url_encode(value.to_s)
    end

    # A term, as the node takes it. A bare string goes through untouched: the
    # node reads it as a national code or as a name, whichever it turns out to
    # be, and keeps it as written when it is neither — the national catalogue is
    # still being assembled, and an exam it has not reached is still an exam.
    def reference(value, name)
      case value
      when nil then nil
      when Hash, String then value
      else raise ArgumentError, "#{name} takes a national code, a name or a hash, not #{value.class}"
      end
    end
  end
end
