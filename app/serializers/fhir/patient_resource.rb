# frozen_string_literal: true

module Fhir
  # The person the sample came from.
  #
  # The name is emitted as `text` only. FHIR's HumanName wants family and given
  # parts, and this database holds one string that an EMR typed: splitting it on
  # spaces would put "Ana Maria" in the family name of half the country's
  # patients, and a name that is wrong in a structured field is worse than one
  # that is right in an unstructured one.
  class PatientResource
    TYPE = "Patient"

    def self.call(patient) = new(patient).as_json
    def self.reference(patient) = { reference: "#{TYPE}/#{patient.uuid}", display: patient.name }

    def initialize(patient)
      @patient = patient
    end

    def as_json
      {
        resourceType: TYPE,
        id: @patient.uuid,
        identifier: identifiers,
        active: true,
        name: [ { text: @patient.name } ],
        telecom: telecom,
        gender: Fhir::SEX.fetch(@patient.sex, "unknown"),
        birthDate: @patient.birthdate&.iso8601
      }.compact
    end

    private

    # A great many patients arrive without a national identifier, and one is
    # never invented for them, so the array is genuinely empty rather than
    # carrying a placeholder an EMR might match on.
    def identifiers
      return [] if @patient.national_id.blank?

      [ { use: "official", system: Fhir.national_id_system, value: @patient.national_id } ]
    end

    def telecom
      return if @patient.phone.blank?

      [ { system: "phone", value: @patient.phone } ]
    end
  end
end
