# frozen_string_literal: true

module Api
  module V3
    # Where a local node says it is alive and how it is getting on.
    #
    # Silence from a laboratory otherwise looks exactly like a laboratory with
    # nothing to send, and the difference between those two is the whole
    # question a national operator has.
    class NodesController < Api::BaseController
      def heartbeat
        return unless authorize_scope!("sync:push")
        return unless node_code
        return unless authorize_facility!(node_code)

        node = Node.heard_from!(node_code, heartbeat_params.except(:node_code).to_h.symbolize_keys)

        # The answer tells the node how far the national dictionary has moved,
        # so an operator standing at the node can see it is behind without
        # having to ask the capital.
        render_data({
                      node_code: node.node_code,
                      last_seen_at: node.last_seen_at.iso8601,
                      dictionary_cursor: Dictionary.cursor
                    })
      end

      private

      def node_code
        return @node_code if defined?(@node_code)

        @node_code = params[:node_code].presence
        return @node_code if @node_code

        render_api_error(Errors::UNPROCESSABLE, message: "é preciso indicar node_code", field: "node_code")
        nil
      end

      def heartbeat_params
        params.permit(:node_code, :name, :version, :dictionary_cursor,
                      :outbox_pending, :outbox_failing, :last_error)
      end
    end
  end
end
