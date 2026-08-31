# frozen_string_literal: true

module Fhir
  # What the laboratory has said about each test.
  #
  # One report per test, and the readings inlined in `contained` rather than
  # only referenced: an EMR that has just been told a report is final wants the
  # values, and making it fetch each Observation by identifier turns one answer
  # into five calls over a link that drops.
  class DiagnosticReportsController < Fhir::BaseController
    def show
      return unless authorize_scope!("results:read")

      order_test = OrderTest.joins(:order).find_by!(uuid: params[:id])
      return unless authorize_facility!(order_test.order.sending_facility_code)

      render_resource(Fhir::DiagnosticReportResource.call(order_test, contained: true))
    end

    def index
      return unless authorize_scope!("results:read")

      reports = search.limit(count).to_a

      render_resource(
        Fhir::Bundle.searchset(
          reports.map { |order_test| Fhir::DiagnosticReportResource.call(order_test, contained: true) },
          base_url: fhir_base_url,
          self_url: search_url
        )
      )
    end

    private

    def search
      relation = OrderTest.joins(order: :patient)
                          .includes(:test_type, { test_results: :indicator }, order: %i[patient rejection_reason])
                          .order(id: :desc)

      relation = facility_scope(relation)
      relation = by_tracking_number(relation)
      relation = by_patient(relation)
      by_status(relation)
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

    def by_status(relation)
      status = params[:status].presence
      return relation if status.blank?

      # `corrected` is a property of the readings, not of the test, so it is not
      # in the table: a corrected report is a final one whose values moved.
      native = Fhir::TEST_STATUS.select { |_, mapped| mapped == status }.keys
      relation.where(order_tests: { status: native })
    end
  end
end
