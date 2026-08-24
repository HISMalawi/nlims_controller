# frozen_string_literal: true

module Fhir
  # How a dictionary entry is codified on the wire.
  #
  # Two codings, in this order, and the order is the point: the national code
  # first because it is what this country runs on and it is always present, and
  # LOINC second, only where somebody has curated it. A client that understands
  # LOINC finds it; a client that does not still gets a code it can act on.
  #
  # The catalogue arrived with no LOINC codes at all, so emitting only LOINC
  # would have made almost every report uncodeable, and emitting only MOZ codes
  # would make a report leaving the country unreadable. Emitting both means the
  # curation improves the wire format on its own, without a client changing a
  # line — which is why this is the only place either system is named.
  class CodeableConcept
    def self.call(entry, text: nil)
      return if entry.nil?

      new(entry, text: text).as_json
    end

    # For the handful of concepts that are ours and have no dictionary row —
    # a status, a category — where a plain code in a named system is all that
    # is meant.
    def self.plain(system:, code:, display: nil)
      concept = { coding: [ { system: system, code: code }.compact ] }
      concept[:coding][0][:display] = display if display
      concept.merge(text: display || code)
    end

    def initialize(entry, text: nil)
      @entry = entry
      @text = text
    end

    def as_json
      { coding: codings, text: @text || @entry.name }
    end

    private

    def codings
      [ national_coding, loinc_coding ].compact
    end

    def national_coding
      {
        system: Fhir.code_system(@entry.class.entity_type),
        code: @entry.national_code,
        display: @entry.name
      }
    end

    # Silence rather than a guess. A LOINC coding that is not in the dictionary
    # would be one this node invented, and a wrong LOINC code states confidently
    # that a test is something it is not — to every system that reads it.
    def loinc_coding
      code = @entry.try(:loinc_code)
      return if code.blank?

      { system: Fhir::LOINC_SYSTEM, code: code, display: @entry.name }
    end
  end
end
