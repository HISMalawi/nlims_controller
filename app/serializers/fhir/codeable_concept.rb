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
  # A term the dictionary does not carry is emitted too, as a concept with the
  # code it arrived with and no system — the same shape this node accepts on the
  # way in — or, where there was no code either, as text alone, which is what
  # FHIR provides for precisely this. Leaving it out instead would drop the exam
  # from the resource and leave a client reading a report of nothing.
  class CodeableConcept
    def self.call(term, text: nil)
      return if term.nil?
      return if term.is_a?(Dictionary::Reference) && term.blank?

      new(term, text: text).as_json
    end

    # For the handful of concepts that are ours and have no dictionary row —
    # a status, a category — where a plain code in a named system is all that
    # is meant.
    def self.plain(system:, code:, display: nil)
      concept = { coding: [ { system: system, code: code }.compact ] }
      concept[:coding][0][:display] = display if display
      concept.merge(text: display || code)
    end

    def initialize(term, text: nil)
      @reference = term.is_a?(Dictionary::Reference) ? term : nil
      @entry = @reference ? @reference.entry : term
      @text = text
    end

    def as_json
      { coding: codings, text: @text || label }
    end

    private

    def label
      @entry&.name.presence || @reference&.label
    end

    def codings
      return [ national_coding, loinc_coding ].compact if @entry

      # No entry to codify. The code the request was written with is still worth
      # carrying, but this node cannot say what system it belongs to without
      # inventing one.
      code = @reference&.code
      return [] if code.blank?

      [ { code: code, display: label }.compact ]
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
