# frozen_string_literal: true

module Dictionary
  # Publishing. An import leaves everything as a draft; this is the deliberate
  # act that makes entries national and starts them travelling down the delta to
  # every laboratory.
  #
  # It is the only control there is. With no released versions to approve, the
  # promotion is the approval, so it always records who did it.
  class Promotion
    # Entries a laboratory cannot actually use. Promoting them puts unusable
    # tests in front of a clinician, so they can be held back in bulk.
    BLOCKING_ISSUES = %w[
      test_type_without_indicators
      test_type_without_specimen_types
    ].freeze

    attr_reader :promoted, :held_back

    def initialize(actor:, entities: Dictionary::ENTITIES.keys, skip_blocked: false)
      @actor = actor
      @entities = entities
      @skip_blocked = skip_blocked
      @promoted = Hash.new(0)
      @held_back = Hash.new(0)
    end

    def call
      ApplicationRecord.transaction do
        @entities.each { |entity_type| promote(entity_type) }
      end

      self
    end

    def summary
      lines = @entities.filter_map do |entity_type|
        next if @promoted[entity_type].zero? && @held_back[entity_type].zero?

        format("  %-16s %4d promovidos  %4d retidos", entity_type, @promoted[entity_type], @held_back[entity_type])
      end

      lines.presence&.join("\n") || "  nada para promover"
    end

    private

    def promote(entity_type)
      model = Dictionary.model_for!(entity_type)

      model.drafts.find_each do |entry|
        if blocked?(entry)
          @held_back[entity_type] += 1
          next
        end

        entry.activate!(actor: @actor)
        @promoted[entity_type] += 1
      end
    end

    def blocked?(entry)
      return false unless @skip_blocked

      blocked_uuids.include?(entry.uuid)
    end

    def blocked_uuids
      @blocked_uuids ||= QualityReport.new.rows
                                      .select { |issue| BLOCKING_ISSUES.include?(issue.issue) }
                                      .to_set { |issue| uuid_for(issue) }
                                      .compact
    end

    def uuid_for(issue)
      Dictionary.model_for!(issue.entity_type).where(national_code: issue.national_code).pick(:uuid)
    end
  end
end
