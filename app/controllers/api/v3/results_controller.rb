# frozen_string_literal: true

module Api
  module V3
    # How an EMR collects results without being told where to look.
    #
    # It polls one cursor and gets everything new for its facility, rather than
    # asking after each order it ever raised. The cursor is a revision from a
    # locked counter, not a timestamp, so a result committed slowly can never
    # slip behind a cursor that has already moved past it.
    class ResultsController < Api::BaseController
      MAX_LIMIT = 500
      DEFAULT_LIMIT = 100

      def index
        return unless authorize_scope!("results:read")

        results = feed.limit(limit).to_a
        next_cursor = results.last&.revision || cursor

        render_data(
          results.map { |result| TestResultSerializer.call(result, context: true) },
          meta: { cursor: cursor, next_cursor: next_cursor, has_more: more_after?(next_cursor, results) }
        )
      end

      private

      def feed
        TestResult.changed_since(cursor)
                  .for_facility(Current.api_client.facility_code)
                  .for_patient_national_id(params[:patient_national_id])
                  .includes(:indicator, order_test: [ :test_type, { order: :patient } ])
      end

      def more_after?(next_cursor, results)
        return false if results.length < limit

        feed.unscope(:includes).where(revision: ((next_cursor + 1)..)).exists?
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
