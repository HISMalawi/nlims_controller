# frozen_string_literal: true

module Fhir
  # What one test says.
  #
  # One report per test rather than one per sample, matching the ServiceRequest
  # it is based on: a panel of three can have one test completed, one running
  # and one rejected, and a single report over the sample would have to claim
  # one status for all three.
  class DiagnosticReportResource
    TYPE = "DiagnosticReport"

    CATEGORY = {
      system: "http://terminology.hl7.org/CodeSystem/v2-0074",
      code: "LAB",
      display: "Laboratory"
    }.freeze

    def self.call(order_test, contained: false) = new(order_test, contained: contained).as_json
    def self.reference(order_test) = { reference: "#{TYPE}/#{order_test.uuid}" }

    # `contained` inlines the observations instead of only referencing them, so
    # an EMR that wants the readings does not have to make one call per row it
    # already knows the identifier of.
    def initialize(order_test, contained: false)
      @order_test = order_test
      @order = order_test.order
      @contained = contained
    end

    def as_json
      json = {
        resourceType: TYPE,
        id: @order_test.uuid,
        meta: { versionId: @order.revision.to_s, lastUpdated: @order_test.updated_at&.iso8601 }.compact,
        extension: [
          { url: Fhir.test_status_extension, valueCode: @order_test.status },
          { url: Fhir.order_status_extension, valueCode: @order.status }
        ],
        identifier: [ { system: Fhir.tracking_number_system, value: @order.tracking_number } ],
        basedOn: [ Fhir::ServiceRequestResource.reference(@order_test) ],
        status: status,
        category: [ { coding: [ CATEGORY ], text: "Laboratory" } ],
        code: Fhir::CodeableConcept.call(@order_test.test_type_reference),
        subject: Fhir::PatientResource.reference(@order.patient),
        specimen: [ Fhir::SpecimenResource.reference(@order) ],
        effectiveDateTime: @order.collected_at&.iso8601,
        issued: issued&.iso8601,
        performer: performer,
        result: current_results.map { |result| Fhir::ObservationResource.reference(result) },
        conclusion: conclusion
      }.compact

      return json unless @contained

      json.merge(contained: current_results.map { |result| Fhir::ObservationResource.call(result) })
    end

    private

    # A report whose readings include a correction is `corrected`, not `final`.
    # It is the one thing a client that already filed this report has to be told,
    # and the test's own status cannot say it: a corrected reading does not
    # reopen the test, it is a new row on a test that stays completed.
    def status
      mapped = Fhir::TEST_STATUS.fetch(@order_test.status, "unknown")
      return "corrected" if mapped == "final" && corrected?

      mapped
    end

    def corrected?
      all_results.any?(&:replaced?)
    end

    def all_results
      @all_results ||= @order_test.test_results.to_a
    end

    def current_results
      @current_results ||= all_results.reject(&:replaced?).sort_by { |result| [ result.recorded_at, result.id ] }
    end

    def issued
      current_results.map(&:recorded_at).compact.max
    end

    def performer
      lab = @order.claimed_by_lab_code.presence || @order.receiving_lab_code.presence
      return if lab.nil?

      [ { identifier: { system: Fhir.url("sid/lab-code"), value: lab }, display: lab } ]
    end

    # Why there is no result, when there is none to give. A rejected test that
    # reported nothing is otherwise indistinguishable from one still running.
    def conclusion
      return unless @order_test.status == OrderTest::REJECTED

      @order.rejection_reason&.name || "Teste rejeitado"
    end
  end
end
