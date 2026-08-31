# frozen_string_literal: true

module Fhir
  # One requested test.
  #
  # A ServiceRequest is one test, not one order: FHIR's `code` is a single
  # concept, and an order here routinely carries several tests that are
  # rejected, referred and reported independently. The tests of one sample are
  # tied together by `requisition`, which is the tracking number — the same
  # grouping HL7 v2 calls the placer group number, and the same number written
  # on the tube.
  class ServiceRequestResource
    TYPE = "ServiceRequest"

    LAB_CATEGORY = { system: "http://snomed.info/sct", code: "108252007", display: "Laboratory procedure" }.freeze

    def self.call(order_test) = new(order_test).as_json
    def self.reference(order_test) = { reference: "#{TYPE}/#{order_test.uuid}" }

    def initialize(order_test)
      @order_test = order_test
      @order = order_test.order
    end

    def as_json
      {
        resourceType: TYPE,
        id: @order_test.uuid,
        meta: meta,
        extension: extensions,
        identifier: [ { system: Fhir.tracking_number_system, value: @order.tracking_number } ],
        requisition: { system: Fhir.tracking_number_system, value: @order.tracking_number },
        status: Fhir::ORDER_STATUS.fetch(@order.status, "unknown"),
        intent: Fhir::INTENT,
        priority: Fhir::ORDER_PRIORITY[@order.priority],
        category: [ { coding: [ LAB_CATEGORY ], text: "Laboratory procedure" } ],
        code: Fhir::CodeableConcept.call(@order_test.test_type_reference),
        orderDetail: order_detail,
        subject: Fhir::PatientResource.reference(@order.patient),
        specimen: [ Fhir::SpecimenResource.reference(@order) ],
        authoredOn: @order.created_at&.iso8601,
        requester: requester,
        performer: performer,
        locationCode: location_code,
        note: note
      }.compact
    end

    private

    def meta
      { versionId: @order.revision.to_s, lastUpdated: @order.updated_at&.iso8601 }.compact
    end

    # What FHIR's own vocabulary cannot say. `active` covers everything from a
    # request nobody has looked at to a sample already on an analyser, and
    # `revoked` covers both a clinic cancelling and a laboratory refusing the
    # sample — which are the difference between drawing a second tube and not.
    def extensions
      list = [
        { url: Fhir.order_status_extension, valueCode: @order.status },
        { url: Fhir.test_status_extension, valueCode: @order_test.status }
      ]

      # The panel this test was expanded out of. The panel is not itself
      # requested — the laboratory runs its members one at a time — but a client
      # that ordered "hemograma completo" has to be able to recognise the tests
      # it got back as that panel.
      panel = Fhir::CodeableConcept.call(@order_test.test_panel_reference)
      list << { url: Fhir.url("StructureDefinition/test-panel"), valueCodeableConcept: panel } if panel

      list
    end

    def order_detail
      return if @order_test.method_of_testing.blank?

      [ { text: @order_test.method_of_testing } ]
    end

    # A name typed by an EMR, not a Practitioner this node has a record of. It
    # is emitted as a display-only reference rather than as a made-up
    # Practitioner id that would 404 the moment anyone followed it.
    def requester
      return if @order.requested_by.blank?

      { display: @order.requested_by }
    end

    def performer
      return if @order.receiving_lab_code.blank?

      [ { identifier: { system: Fhir.url("sid/lab-code"), value: @order.receiving_lab_code },
          display: @order.receiving_lab_code } ]
    end

    def location_code
      return if @order.order_location.blank?

      [ { text: @order.order_location } ]
    end

    def note
      return if @order.clinical_history.blank?

      [ { text: @order.clinical_history } ]
    end
  end
end
