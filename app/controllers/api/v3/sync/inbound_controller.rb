# frozen_string_literal: true

module Api
  module V3
    module Sync
      # What the national node is holding for a node: samples referred to it,
      # and results produced elsewhere on samples it sent away.
      #
      # A pull rather than a push, like everything else between nodes — a
      # laboratory behind a router nobody administers cannot be called.
      class InboundController < Api::BaseController
        MAX_LIMIT = 500
        DEFAULT_LIMIT = 100

        def index
          return unless authorize_scope!("sync:pull")
          return unless node_code
          return unless authorize_node!(node_code)

          deliveries = feed.limit(limit).to_a
          next_cursor = deliveries.last&.revision || cursor

          render_data(
            deliveries.map { |delivery| wire(delivery) },
            meta: { cursor: cursor, next_cursor: next_cursor, node_code: node_code,
                    has_more: more_after?(next_cursor, deliveries) }
          )
        end

        private

        def feed
          InboundDelivery.for_node(node_code).changed_since(cursor).includes(:inbound_event)
        end

        def more_after?(next_cursor, deliveries)
          return false if deliveries.length < limit

          InboundDelivery.for_node(node_code).changed_since(next_cursor).exists?
        end

        # The event as its origin sent it, plus the node it came from: a node
        # applying it has to keep each origin's stream in its own order, and two
        # origins number their events independently.
        def wire(delivery)
          event = delivery.inbound_event

          {
            revision: delivery.revision,
            node_code: event.node_code,
            event_uuid: event.event_uuid,
            aggregate_uuid: event.aggregate_uuid,
            sequence: event.sequence,
            type: event.type,
            occurred_at: event.occurred_at.iso8601,
            payload: event.payload
          }
        end

        def node_code
          return @node_code if defined?(@node_code)

          @node_code = params[:node_code].presence || Current.api_client.facility_code.presence
          return @node_code if @node_code

          render_api_error(Errors::UNPROCESSABLE, message: "é preciso indicar node_code", field: "node_code")
          nil
        end

        def cursor
          @cursor ||= params[:since].to_i.clamp(0, Float::INFINITY).to_i
        end

        def limit
          @limit ||= (params[:limit].presence || DEFAULT_LIMIT).to_i.clamp(1, MAX_LIMIT)
        end
      end
    end
  end
end
