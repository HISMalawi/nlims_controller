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

        # Everything at this unit that changed since the cursor — not only what
        # is still open. An order cancelled at the clinic after the laboratory
        # took it is exactly what that laboratory has to be told about, and a
        # feed that hid it would leave a sample being worked on that nobody
        # wants.
        #
        # The unit is the scope, because the node is the unit. An mLab instance
        # polling for one of its benches sends `lab_code` and gets that bench's
        # work plus everything still unclaimed; sending nothing gets the whole
        # unit, which is what an instance that dispatches its own benches wants.
        def pending
          return unless authorize_scope!("orders:read")

          orders = feed.limit(limit).to_a
          next_cursor = orders.last&.revision || cursor

          render_data(
            orders.map { |order| OrderSerializer.call(order) },
            meta: { cursor: cursor, next_cursor: next_cursor, facility_code: facility_code,
                    lab_code: lab_code, has_more: more_after?(next_cursor, orders) }
          )
        end

        # Taking the sample. The laboratory says which of the unit's benches is
        # taking it: an order raised by an EMR arrived at the unit with no
        # laboratory on it, and this is where it acquires one.
        def claim
          return unless authorize_scope!("orders:read")
          return unless load_order
          return unless claiming_lab

          @order.claim!(lab_code: claiming_lab, actor: Current.api_client.name)

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
          reason = Dictionary::Reference.resolve!("rejection_reasons", rejection[:reason], field: "reason",
                                                   message: "é preciso indicar o motivo da rejeição")
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
          payload.permit(tests: [ :method_of_testing, { test_type: Dictionary::Reference::ATTRIBUTES } ])
        end

        def rejection_params
          payload.permit(:note, reason: Dictionary::Reference::ATTRIBUTES)
        end

        def report_params
          payload.permit(
            :final,
            results: [
              :value, :unit, :recorded_at, :recorded_by,
              { test_type: Dictionary::Reference::ATTRIBUTES, indicator: Dictionary::Reference::ATTRIBUTES }
            ]
          )
        end

        def load_order
          @order = Order.find_by_tracking_number!(params[:tracking_number])

          authorize_facility!(@order.receiving_facility_code)
        end

        # Scoped to the unit, and narrowed to one bench when the caller names
        # one. Unclaimed work stays in every bench's feed: until somebody takes
        # it, it is nobody's and anybody's.
        def feed
          scope = Order.changed_since(cursor).for_facility(facility_code)
          scope = scope.where(receiving_lab_code: lab_codes + [ nil ]) if lab_code.present?

          scope.includes(:patient, :specimen_type, order_tests: %i[test_type test_panel])
        end

        # Every code the named laboratory is known by — its own and, once the
        # capital has named it, the national one. Samples keep the code they
        # were written with, so asking by one of them must find both.
        def lab_codes
          @lab_codes ||= begin
            known = ::Lab.find_by_any_code(lab_code, facility_code: facility_code)
            known&.codes.presence || [ lab_code ]
          end
        end

        def more_after?(next_cursor, orders)
          return false if orders.length < limit

          feed.unscope(:includes).where(revision: ((next_cursor + 1)..)).exists?
        end

        # The unit this key speaks for. Filled onto the key when it was issued,
        # so a client never sends it and never gets it wrong.
        def facility_code
          @facility_code ||= Current.api_client&.facility_code.presence || SislabSync.facility_code
        end

        # Which bench, when the caller names one. Optional everywhere it is read
        # for a feed: an mLab instance holds several laboratories under one key,
        # and which of them is asking is its business, not the key's.
        def lab_code
          @lab_code ||= params[:lab_code].presence
        end

        # Which bench is taking the sample. Required, because this is the one
        # place the answer is written down and inferring it would write the
        # wrong laboratory onto somebody's result.
        def claiming_lab
          return @claiming_lab if defined?(@claiming_lab)

          # Written down canonically: the national code where the register has
          # one, so a result is not filed under a code that only means anything
          # inside one mLab instance.
          named = lab_code && ::Lab.find_by_any_code(lab_code, facility_code: facility_code)
          @claiming_lab = named&.code || lab_code || @order.receiving_lab_code.presence
          return @claiming_lab if @claiming_lab

          render_api_error(Errors::UNPROCESSABLE,
                           message: "indique lab_code: o laboratório que está a receber a amostra",
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
