# frozen_string_literal: true

module Fhir
  # The sample itself, addressed by the number written on the tube.
  #
  # There is no specimens table: in this system one order is one sample, so the
  # Specimen is projected from the order and shares its uuid. That is why an
  # order rejected for a haemolysed sample shows here as `unsatisfactory` — the
  # order's rejection is the sample's.
  class SpecimenResource
    TYPE = "Specimen"

    def self.call(order) = new(order).as_json
    def self.reference(order) = { reference: "#{TYPE}/#{order.uuid}", display: order.tracking_number }

    def initialize(order)
      @order = order
    end

    def as_json
      {
        resourceType: TYPE,
        id: @order.uuid,
        identifier: [ { system: Fhir.tracking_number_system, value: @order.tracking_number } ],
        accessionIdentifier: { system: Fhir.tracking_number_system, value: @order.tracking_number },
        status: Fhir::SPECIMEN_STATUS.fetch(@order.status, Fhir::SPECIMEN_STATUS_DEFAULT),
        type: Fhir::CodeableConcept.call(@order.specimen_type_reference),
        subject: Fhir::PatientResource.reference(@order.patient),
        receivedTime: @order.claimed_at&.iso8601,
        collection: collection,
        note: note
      }.compact
    end

    private

    def collection
      return if @order.collected_at.blank?

      { collectedDateTime: @order.collected_at.iso8601 }
    end

    # Why the laboratory refused it, in the words of the dictionary entry the
    # operator chose. A client re-drawing a sample needs the reason, and the
    # order's own status only says that it was refused.
    def note
      return if @order.rejection_reason.nil?

      [ { text: @order.rejection_reason.name } ]
    end
  end
end
