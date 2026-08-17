# frozen_string_literal: true

module Dictionary
  # What an operator may change on a dictionary entry, per entity type.
  #
  # Declared once rather than as eight forms and eight strong-parameter lists.
  # The fields that are missing here are missing on purpose: `national_code`,
  # `uuid`, `revision` and `status` are the identity and the publication state,
  # and each is owned by something other than a text box — the code sequence,
  # the replication, the promotion.
  module Editable
    Field = Struct.new(:name, :kind, :options, keyword_init: true) do
      def collection = options&.fetch(:collection, nil)
    end

    # Every entry carries these. `loinc_code` is here because it is the one
    # curation S11 exists to make possible: the imported catalogue has zero
    # LOINC coverage, and until it has some, no FHIR or HL7 façade over these
    # models would mean anything to anybody outside this country.
    COMMON = [
      Field.new(name: :name, kind: :string),
      Field.new(name: :short_name, kind: :string),
      Field.new(name: :description, kind: :text),
      Field.new(name: :moh_code, kind: :code),
      Field.new(name: :loinc_code, kind: :code)
    ].freeze

    EXTRA = {
      "indicators" => [
        Field.new(name: :unit, kind: :string),
        Field.new(name: :value_type, kind: :select, options: { collection: -> { Indicator::VALUE_TYPES } })
      ],
      "test_types" => [
        Field.new(name: :target_tat, kind: :string),
        Field.new(name: :performed_on_sex, kind: :select, options: { collection: -> { TestType::SEXES } }),
        Field.new(name: :department_id, kind: :belongs_to,
                  options: { collection: -> { Department.active.order(:name) } })
      ]
    }.freeze

    def self.fields_for(entity_type)
      COMMON + EXTRA.fetch(entity_type.to_s, [])
    end

    def self.attribute_names_for(entity_type)
      fields_for(entity_type).map(&:name)
    end
  end
end
