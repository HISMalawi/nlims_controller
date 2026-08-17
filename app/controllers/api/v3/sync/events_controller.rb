# frozen_string_literal: true

module Api
  module V3
    module Sync
      # Where the national node receives what happened in the country.
      #
      # Only the national node answers this: a local node has nothing to receive
      # and no business accepting another node's events.
      class EventsController < Api::BaseController
        MAX_EVENTS = 500

        def create
          return unless authorize_scope!("sync:push")
          return unless node_code
          return unless authorize_facility!(node_code)
          return unless batch_within_limit?

          result = ::Sync::Ingest.new(node_code: node_code, events: events_params).call

          render_data(result.as_json, meta: { node_code: node_code, received: events_params.length })
        end

        private

        def node_code
          return @node_code if defined?(@node_code)

          @node_code = params[:node_code].presence
          return @node_code if @node_code

          render_api_error(Errors::UNPROCESSABLE, message: "é preciso indicar node_code", field: "node_code")
          nil
        end

        # A batch that is too big is refused rather than half-applied: the
        # sender pages it, and paging is something it already knows how to do.
        def batch_within_limit?
          return true if events_params.length <= MAX_EVENTS

          render_api_error(Errors::UNPROCESSABLE,
                           message: "um lote leva no máximo #{MAX_EVENTS} eventos",
                           field: "events")
          false
        end

        def events_params
          @events_params ||= params.permit(
            events: [ :event_uuid, :aggregate_uuid, :sequence, :type, :occurred_at, { payload: {} } ]
          ).fetch(:events, []).map(&:to_h)
        end
      end
    end
  end
end
