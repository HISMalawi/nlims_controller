# frozen_string_literal: true

module Api
  module V3
    module Lab
      # What a SISLAB installation pulls and takes.
      #
      # The laboratory polls; the node never calls the laboratory. That is what
      # lets a SISLAB sit behind a router nobody administers, which is where
      # most of them sit.
      class OrdersController < Api::BaseController
        MAX_LIMIT = 500
        DEFAULT_LIMIT = 100

        # Everything for this laboratory that changed since the cursor — not
        # only what is still open. An order cancelled at the clinic after the
        # laboratory took it is exactly what that laboratory has to be told
        # about, and a feed that hid it would leave a sample being worked on
        # that nobody wants.
        def pending
          return unless authorize_scope!("orders:read")
          return unless lab_code
          return unless authorize_lab!(lab_code)

          orders = feed.limit(limit).to_a
          next_cursor = orders.last&.revision || cursor

          render_data(
            orders.map { |order| OrderSerializer.call(order) },
            meta: { cursor: cursor, next_cursor: next_cursor,
                    lab_code: lab_code, has_more: more_after?(next_cursor, orders) }
          )
        end

        def claim
          return unless authorize_scope!("orders:read")
          return unless load_order

          @order.claim!(lab_code: @order.receiving_lab_code, actor: Current.api_client.name)

          render_data(OrderSerializer.call(@order))
        rescue Order::AlreadyClaimed => e
          render_api_error(Errors::CONFLICT, message: e.message)
        end

        # An illegal transition is refused by the model before anything is
        # written, and arrives here as the 422 every endpoint renders.
        def status
          return unless authorize_scope!("results:write")
          return unless load_order

          @order.transition_to!(params[:status], actor: actor, reason: params[:reason])

          render_data(OrderSerializer.call(@order, history: true))
        end

        def results
          return unless authorize_scope!("results:write")
          return unless load_order

          LabReport.new(@order, report_params, actor: actor).record!

          render_data(OrderSerializer.call(@order, results: true))
        end

        # A test the clinician did not ask for but the laboratory ran anyway —
        # a confirmation, a reflex test, something the first result made
        # necessary. It goes on the sample that was already taken, under the
        # tracking number the clinic is already waiting on, rather than becoming
        # a second order nobody at the clinic recognises.
        def tests
          return unless authorize_scope!("results:write")
          return unless load_order

          added = AddedTests.new(@order, tests_params, actor: actor).add!

          render_data(OrderSerializer.call(@order), meta: { added: added.length }, status: :created)
        end

        def reject
          return unless authorize_scope!("results:write")
          return unless load_order

          rejection = rejection_params
          reason = Dictionary.entry!("rejection_reasons", rejection[:reason], field: "reason")
          @order.reject!(reason: reason, actor: actor, note: rejection[:note])

          render_data(OrderSerializer.call(@order, history: true))
        end

        private

        # The technician, when the laboratory names one. The key identifies the
        # installation, not the person who read the slide.
        def actor
          params[:actor].presence || Current.api_client.name
        end

        def tests_params
          params.permit(tests: [ :method_of_testing, { test_type: %i[national_code uuid] } ])
        end

        def rejection_params
          params.permit(:note, reason: %i[national_code uuid])
        end

        def report_params
          params.permit(
            :final,
            results: [
              :value, :unit, :recorded_at, :recorded_by,
              { test_type: %i[national_code uuid], indicator: %i[national_code uuid] }
            ]
          )
        end

        def load_order
          @order = Order.find_by_tracking_number!(params[:tracking_number])

          authorize_lab!(@order.receiving_lab_code)
        end

        def feed
          Order.changed_since(cursor)
               .for_lab(lab_code)
               .includes(:patient, :specimen_type, order_tests: %i[test_type test_panel])
        end

        def more_after?(next_cursor, orders)
          return false if orders.length < limit

          feed.unscope(:includes).where(revision: ((next_cursor + 1)..)).exists?
        end

        # The key knows which laboratory it speaks for, so the parameter is only
        # there for a client that speaks for several — and it still has to
        # match the key.
        def lab_code
          return @lab_code if defined?(@lab_code)

          @lab_code = params[:lab_code].presence || Current.api_client.lab_code
          return @lab_code if @lab_code.present?

          render_api_error(Errors::UNPROCESSABLE,
                           message: "esta chave não está associada a um laboratório; indique lab_code",
                           field: "lab_code")
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
