# frozen_string_literal: true

module Fhir
  # How an EMR collects readings without being told where to look.
  #
  # `_since` is a revision from a locked counter, not a timestamp: a result that
  # committed slowly can never slip behind a cursor that has already moved past
  # it, which a `_lastUpdated` search cannot promise. The client follows the
  # bundle's `next` link until there is none, keeps the cursor it ended on, and
  # starts from there next time.
  #
  # Corrections travel on the same feed. A reading that was superseded moves
  # again when it is marked, and arrives as an Observation with status
  # `entered-in-error` naming its replacement, so a client that filed the wrong
  # value learns of it by polling and not by being lucky.
  class ObservationsController < Fhir::BaseController
    def show
      return unless authorize_scope!("results:read")
      return unless load_result

      render_resource(Fhir::ObservationResource.call(@result))
    end

    def index
      return unless authorize_scope!("results:read")

      results = search.limit(count).to_a
      next_cursor = results.last&.revision || cursor

      render_resource(
        Fhir::Bundle.searchset(
          results.map { |result| Fhir::ObservationResource.call(result) },
          base_url: fhir_base_url,
          self_url: search_url,
          next_url: (search_url(_since: next_cursor) if results.length >= count)
        )
      )
    end

    # Confirming that the EMR has filed a reading. There is no FHIR element for
    # it — acknowledgement is between these two systems and nobody else — so it
    # is an operation rather than a field an EMR might try to PUT.
    def acknowledge
      return unless authorize_scope!("results:read")
      return unless load_result
      return if refuse_superseded

      @result.acknowledge!(by: Current.api_client.name)

      render_resource(Fhir::ObservationResource.call(@result))
    end

    private

    def load_result
      @result = TestResult.joins(order_test: :order).find_by!(uuid: params[:id])

      authorize_facility!(@result.order_test.order.sending_facility_code)
    end

    # Filing a reading that has since been corrected is the mistake the whole
    # replacement design exists to prevent, so it is refused and the replacement
    # is named.
    def refuse_superseded
      return false unless @result.replaced?

      render_api_error(
        Api::Errors::CONFLICT,
        message: "este resultado foi substituído por #{@result.replaced_by_uuid}; " \
                 "obtenha a correcção antes de confirmar"
      )
      true
    end

    def search
      relation = TestResult.changed_since(cursor)
                           .joins(order_test: { order: :patient })
                           .includes(:indicator, order_test: [ :test_type, { order: :patient } ])

      relation = facility_scope(relation)
      relation = by_tracking_number(relation)
      by_patient(relation)
    end

    def by_tracking_number(relation)
      tracking = token_value(params[:identifier])
      return relation if tracking.blank?

      relation.where(orders: { tracking_number: tracking })
    end

    def by_patient(relation)
      national_id = token_value(params[:"patient.identifier"] || params[:"subject.identifier"])
      if national_id.present?
        return relation.where(patients: { national_id: Patient.normalize_value_for(:national_id, national_id) })
      end

      uuid = params[:patient].presence || params[:subject].presence
      return relation if uuid.blank?

      relation.where(patients: { uuid: uuid.to_s.delete_prefix("Patient/") })
    end

    def cursor
      @cursor ||= params[:_since].to_i.clamp(0, Float::INFINITY).to_i
    end
  end
end
