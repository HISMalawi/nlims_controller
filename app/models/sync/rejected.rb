# frozen_string_literal: true

module Sync
  # An event the national node cannot apply, with a code the sender can act on.
  #
  # A rejection is not a log line. It goes back in the response, stays on the
  # event, and shows up in the sync queue, because the usual cause is two nodes
  # disagreeing about something an administrator has to reconcile — most often a
  # dictionary the sender has not caught up with.
  class Rejected < StandardError
    UNKNOWN_TYPE = "unknown_type"
    MALFORMED = "malformed"
    UNKNOWN_AGGREGATE = "unknown_aggregate"
    UNKNOWN_DICTIONARY_ITEM = "unknown_dictionary_item"
    INVALID = "invalid"
    APPLY_FAILED = "apply_failed"

    attr_reader :code

    def initialize(code, message)
      super(message)
      @code = code
    end
  end
end
