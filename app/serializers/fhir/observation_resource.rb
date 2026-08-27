# frozen_string_literal: true

module Fhir
  # One reading against one indicator.
  #
  # Nothing recorded here is ever rewritten: a correction is a new row, and the
  # row it corrects is marked as superseded. FHIR says exactly that with
  # `entered-in-error`, which is the instruction "disregard this" — and the
  # extension names the reading that replaced it, so a client that already filed
  # the wrong value can go and get the right one rather than hunting for it.
  class ObservationResource
    TYPE = "Observation"

    CATEGORY = {
      system: "http://terminology.hl7.org/CodeSystem/observation-category",
      code: "laboratory",
      display: "Laboratory"
    }.freeze

    UCUM = "http://unitsofmeasure.org"

    def self.call(result) = new(result).as_json
    def self.reference(result) = { reference: "#{TYPE}/#{result.uuid}" }

    def initialize(result)
      @result = result
      @order_test = result.order_test
      @order = @order_test.order
    end

    def as_json
      {
        resourceType: TYPE,
        id: @result.uuid,
        meta: { versionId: @result.revision.to_s, lastUpdated: @result.updated_at&.iso8601 }.compact,
        extension: extensions,
        identifier: [ { system: Fhir.tracking_number_system, value: @order.tracking_number } ],
        basedOn: [ Fhir::ServiceRequestResource.reference(@order_test) ],
        status: status,
        category: [ { coding: [ CATEGORY ], text: "Laboratory" } ],
        code: Fhir::CodeableConcept.call(@result.indicator_reference),
        subject: Fhir::PatientResource.reference(@order.patient),
        specimen: Fhir::SpecimenResource.reference(@order),
        # When the sample was taken, not when somebody typed the number in. The
        # clinical question is always what the patient's value was, and that is
        # the moment of collection.
        effectiveDateTime: (@order.collected_at || @result.recorded_at)&.iso8601,
        issued: @result.recorded_at&.iso8601,
        performer: performer,
        referenceRange: reference_ranges.presence
      }.compact.merge(value)
    end

    private

    # `final` or "disregard this". The intermediate `preliminary` and `amended`
    # have no counterpart here: a reading exists only once it has been recorded,
    # and it is never amended in place.
    def status
      @result.replaced? ? "entered-in-error" : "final"
    end

    def extensions
      list = [ { url: Fhir.revision_extension, valueInteger: @result.revision } ]

      if @result.replaced?
        list << { url: Fhir.url("StructureDefinition/replaced-by"),
                  valueString: @result.replaced_by_uuid }
      end

      if @result.acknowledged_at
        list << { url: Fhir.url("StructureDefinition/acknowledged-at"),
                  valueDateTime: @result.acknowledged_at.iso8601 }
      end

      list
    end

    def performer
      return if @result.recorded_by.blank?

      [ { display: @result.recorded_by } ]
    end

    # A quantity only where the dictionary says the indicator is numeric *and*
    # the recorded text really parses as a number. A qualitative reading, a
    # "<40" and a free-text comment all travel as `valueString`, because a
    # client that receives valueQuantity is entitled to do arithmetic on it.
    def value
      number = numeric_value
      return { valueString: @result.value.to_s } if number.nil?

      quantity = { value: number }
      # `unit` is the display string the laboratory uses. No `system`/`code` is
      # emitted with it: the dictionary's units are not UCUM, and labelling them
      # as UCUM would invite a client to convert between two units that only
      # look like the ones it knows.
      quantity[:unit] = unit if unit.present?

      { valueQuantity: quantity }
    end

    def numeric_value
      return nil unless @result.indicator.value_type == "Numeric"

      Float(@result.value.to_s.strip)
    rescue ArgumentError, TypeError
      nil
    end

    def unit
      @unit ||= @result.unit.presence || @result.indicator.unit.presence
    end

    # Only the intervals that apply to this patient. Shipping a newborn's range
    # alongside an adult's leaves the reader to work out which one is meant,
    # and that is the decision the range exists to have already made.
    def reference_ranges
      @result.indicator.indicator_ranges.select { |range| applies?(range) }.map { |range| range_json(range) }
    end

    def applies?(range)
      return false unless range.sex == "Both" || range.sex == @order.patient.sex
      return true if age_in_years.nil?

      (range.age_min.nil? || age_in_years >= range.age_min) &&
        (range.age_max.nil? || age_in_years <= range.age_max)
    end

    def range_json(range)
      {
        low: simple_quantity(range.range_lower),
        high: simple_quantity(range.range_upper),
        type: interpretation_concept(range),
        age: age_range(range),
        text: range.value.presence || range.interpretation.presence
      }.compact
    end

    def simple_quantity(value)
      return if value.nil?

      { value: value.to_f, unit: unit }.compact
    end

    def interpretation_concept(range)
      return if range.interpretation.blank?

      { text: range.interpretation }
    end

    # Years, which is what the dictionary stores, said in UCUM so it cannot be
    # read as months by a client that guessed.
    def age_range(range)
      return if range.age_min.nil? && range.age_max.nil?

      {
        low: range.age_min && { value: range.age_min, unit: "a", system: UCUM, code: "a" },
        high: range.age_max && { value: range.age_max, unit: "a", system: UCUM, code: "a" }
      }.compact
    end

    def age_in_years
      return @age_in_years if defined?(@age_in_years)

      birthdate = @order.patient.birthdate
      @age_in_years = birthdate && ((@order.collected_at || @result.recorded_at || Time.current).to_date - birthdate).to_i / 365
    end
  end
end
