# frozen_string_literal: true

module SislabSyncClient
  # What one node says to another — in practice, what a facility node says to
  # the capital.
  #
  # The local node always initiates, in both directions: it pushes its outbox
  # and it pulls what is waiting. Laboratories sit behind NAT with no fixed
  # address, so the national node could not call them if it wanted to.
  #
  # This profile is here so that a ministry writing its own node, or a test
  # harness standing in for one, does not have to re-derive the sequencing
  # rules from the contract.
  class Node < Profile
    # A batch has a ceiling. Over it the node refuses the whole batch rather
    # than applying half of it, so the sender pages — which it already knows how
    # to do.
    MAX_EVENTS = 500

    # Hands over what happened here. Delivery is at-least-once and storing is
    # idempotent by `event_uuid`, so the same batch arriving twice — because the
    # answer was lost, not the request — is recognised rather than duplicated.
    #
    # Applying happens in sequence per aggregate. An event whose predecessor has
    # not arrived waits where it is; the answer's `rejected` names anything the
    # capital could not apply, and a rejection blocks the rest of that sample's
    # stream and nothing else.
    def push_events(node_code:, events:)
      events = Array(events)
      if events.length > MAX_EVENTS
        raise ArgumentError, "a batch takes at most #{MAX_EVENTS} events; page it (#{events.length} given)"
      end

      connection.post("/api/v3/sync/events", { node_code: node_code, events: events }).data
    end

    # What the capital is holding for this node: samples referred to it, and
    # results produced elsewhere on samples it sent away.
    #
    # Each event carries the `node_code` that produced it. A node applying them
    # keeps each origin's stream in its own order — two origins number their
    # events independently, so one global order would be a fiction.
    def inbound(node_code: nil, since: 0, limit: nil)
      params = node_code ? { node_code: node_code } : {}

      Feed.new(connection, "/api/v3/sync/inbound", params, since: since, limit: limit)
    end

    # Says this node is alive and how it is getting on. Silence from a
    # laboratory otherwise looks exactly like a laboratory with nothing to send,
    # and telling those two apart is the whole question a national operator has.
    #
    # The answer says how far the national dictionary has moved, so an operator
    # standing at the node can see it is behind without asking the capital.
    def heartbeat(node_code:, name: nil, version: nil, dictionary_cursor: nil,
                  outbox_pending: nil, outbox_failing: nil, last_error: nil)
      body = {
        node_code: node_code,
        name: name,
        version: version,
        dictionary_cursor: dictionary_cursor,
        outbox_pending: outbox_pending,
        outbox_failing: outbox_failing,
        last_error: last_error
      }.compact

      connection.post("/api/v3/nodes/heartbeat", body).data
    end
  end
end
