# frozen_string_literal: true

# The dictionary as one thing. Entries live in separate tables but share a
# single revision sequence, so a local node walks all of them with one cursor
# instead of one cursor per entity type.
module Dictionary
  ENTITIES = {
    "departments" => "Department",
    "specimen_types" => "SpecimenType",
    "drugs" => "Drug",
    "organisms" => "Organism",
    "indicators" => "Indicator",
    "test_types" => "TestType",
    "test_panels" => "TestPanel"
  }.freeze

  DEFAULT_LIMIT = 500

  class UnknownEntity < StandardError; end

  class << self
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
        model_for!(entity_type).changed_since(cursor).limit(limit).map { |record| [ entity_type, record ] }
      end

      rows.sort_by { |(_, record)| [ record.revision, record.id ] }.first(limit)
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
