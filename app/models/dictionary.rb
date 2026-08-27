# frozen_string_literal: true

# The dictionary as one thing. Entries live in separate tables but share a
# single revision sequence, so a local node walks all of them with one cursor
# instead of one cursor per entity type.
module Dictionary
  ENTITIES = {
    # The register of laboratories rides the dictionary feed rather than a
    # channel of its own: it is a national list, replicated to every node, read
    # by code — which is what the feed already does eight times over.
    "labs" => "Lab",
    "departments" => "Department",
    "specimen_types" => "SpecimenType",
    "drugs" => "Drug",
    "organisms" => "Organism",
    "indicators" => "Indicator",
    "test_types" => "TestType",
    "test_panels" => "TestPanel",
    "rejection_reasons" => "RejectionReason"
  }.freeze

  DEFAULT_LIMIT = 500

  # The links each entity type ships inline. Links carry no revision of their
  # own, so they travel inside the entry that owns them and are addressed by
  # national code — never by an id, which means nothing outside this database.
  LINKS = {
    "organisms" => [
      Link.new(name: :drugs, target_entity: "drugs", join_model_name: "OrganismDrug",
               owner_key: :organism_id, target_key: :drug_id)
    ],
    "test_types" => [
      Link.new(name: :specimen_types, target_entity: "specimen_types", join_model_name: "TestTypeSpecimenType",
               owner_key: :test_type_id, target_key: :specimen_type_id),
      Link.new(name: :indicators, target_entity: "indicators", join_model_name: "TestTypeIndicator",
               owner_key: :test_type_id, target_key: :indicator_id),
      Link.new(name: :organisms, target_entity: "organisms", join_model_name: "TestTypeOrganism",
               owner_key: :test_type_id, target_key: :organism_id)
    ],
    "test_panels" => [
      Link.new(name: :test_types, target_entity: "test_types", join_model_name: "TestPanelTestType",
               owner_key: :test_panel_id, target_key: :test_type_id)
    ]
  }.freeze

  class UnknownEntity < StandardError; end

  class << self
    def links_for(entity_type)
      LINKS.fetch(entity_type.to_s, [])
    end

    def models
      ENTITIES.values.map(&:constantize)
    end

    def model_for(entity_type)
      name = ENTITIES[entity_type.to_s]
      name&.constantize
    end

    def model_for!(entity_type)
      model_for(entity_type) || raise(UnknownEntity, "#{entity_type.inspect} is not a dictionary entity")
    end

    # Everything published after `cursor`, oldest first, across every entity
    # type. Returns [entity_type, record] pairs so a caller knows what each row
    # is without asking the object.
    #
    # Reading more than `limit` from each table and then trimming is deliberate:
    # the caller must be able to stop at a revision boundary it has seen in full.
    def changes_since(cursor, entities: ENTITIES.keys, limit: DEFAULT_LIMIT)
      rows = entities.flat_map do |entity_type|
        model = model_for!(entity_type)

        model.changed_since(cursor)
             .includes(model.delta_includes)
             .limit(limit)
             .map { |record| [ entity_type, record ] }
      end

      rows.sort_by { |(_, record)| [ record.revision, record.id ] }.first(limit)
    end

    # Serialised for the wire, with the cursor a caller should send next.
    # Revisions are globally unique, so a batch can be cut at any point without
    # splitting a revision across two responses.
    def delta(cursor, entities: ENTITIES.keys, limit: DEFAULT_LIMIT)
      rows = changes_since(cursor, entities: entities, limit: limit)
      next_cursor = rows.last&.last&.revision || cursor.to_i

      {
        entries: rows.map { |(entity_type, record)| Serializer.call(entity_type, record) },
        next_cursor: next_cursor,
        has_more: rows.length >= limit && changes_since(next_cursor, entities: entities, limit: 1).any?
      }
    end

    # Where a local node that is fully caught up would leave its cursor.
    def cursor
      Sequence.current(Sequence::DICTIONARY_REVISION)
    end

    def published_counts
      models.index_by(&:entity_type).transform_values { |model| model.published.count }
    end
  end
end
