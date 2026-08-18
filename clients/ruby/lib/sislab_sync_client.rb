# frozen_string_literal: true

require "erb"
require "json"
require "securerandom"

require_relative "sislab_sync_client/version"
require_relative "sislab_sync_client/errors"
require_relative "sislab_sync_client/transport"
require_relative "sislab_sync_client/connection"
require_relative "sislab_sync_client/feed"
require_relative "sislab_sync_client/profile"
require_relative "sislab_sync_client/emr"
require_relative "sislab_sync_client/lab"
require_relative "sislab_sync_client/node"

# The reference client for a SISLAB Sync node.
#
# Three profiles, because there are three integrations and they are not the
# same job: an EMR asks for tests and collects results, a SISLAB takes the work
# and publishes it, and a node hands its events to the capital and pulls back
# what is waiting. Each profile exposes only the endpoints its kind of key is
# allowed to call.
#
# What the three share is what this library is really for: one envelope, one
# way of paging a cursor, one exception per refusal the node can give, and the
# idempotency that makes a retry safe on a line that drops.
#
#   emr = SislabSyncClient.emr(base_url: "http://localhost:3000", api_key: key)
#   emr.me   # => what this key is and what it may do
#
# Stdlib only. A laboratory server that cannot reach rubygems can still install
# this, which is not a hypothetical at a district hospital.
module SislabSyncClient
  class << self
    def emr(...) = Emr.new(...)
    def lab(...) = Lab.new(...)
    def node(...) = Node.new(...)
  end
end
