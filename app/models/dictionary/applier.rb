# frozen_string_literal: true

module Dictionary
  # Writes a batch of feed entries into this node's dictionary.
  #
  # A batch is applied in one transaction, so a node is never left holding half
  # of a change. Entries are matched by uuid: national codes are stable but the
  # uuid is the identity, and matching on the code would break the moment a
  # typo in one was corrected upstream.
  class Applier
    attr_reader :applied, :deferred, :resolved

    BASE_ATTRIBUTES = %i[national_code name short_name description status loinc_code moh_code].freeze
    LAB_ATTRIBUTES = %i[facility_code source_code phone].freeze
    FACILITY_ATTRIBUTES = %i[district province phone].freeze

    def initialize
      @applied = Hash.new(0)
      @deferred = 0
      @resolved = 0
    end

    def apply(entries)
      return self if entries.blank?

      # Symbolised once, up front. Entries arrive as parsed JSON with string
      # keys, and reading revision off those with a symbol silently gave zero —
      # which left the local counter behind the revisions the node was holding.
      normalised = entries.map(&:deep_symbolize_keys)

      # Reset per batch: a target missing in one batch may well arrive in the
      # next, and a cached "not found" would keep its links deferred for ever.
      @resolved_cache = {}

      ApplicationRecord.transaction do
        normalised.each { |entry| apply_entry(entry) }
        resolve_deferrals
        Sequence.ensure_at_least!(Sequence::DICTIONARY_REVISION,
                                  normalised.pluck(:revision).compact.max.to_i)
      end

      self
    end

    def total_applied
      applied.values.sum
    end

    private

    def apply_entry(entry)
      entity_type = entry[:entity].to_s
      raise UnknownEntity, "entry has no entity type" if entity_type.blank?

      model = Dictionary.model_for!(entity_type)

      record = model.find_by(uuid: entry[:uuid]) || adopt_local(model, entity_type, entry) ||
               model.new(uuid: entry[:uuid])
      record.assign_attributes(entry.slice(*BASE_ATTRIBUTES))
      record.deleted_at = entry[:deleted_at]
      record.replicated_revision = entry[:revision]
      assign_extras(record, entity_type, entry)
      record.save!

      apply_ranges(record, entry) if entity_type == "indicators"
      apply_links(record, entity_type, entry)

      # Link changes bump the owner's revision through BumpsOwnerRevision, which
      # would replace the number the national node issued with a local one.
      # Stamp the received revision back on, last.
      record.update_column(:revision, entry[:revision])

      @applied[entity_type] += 1
    end

    # The capital's answer to a laboratory this node registered itself.
    #
    # It normally arrives under the uuid this node sent up, and the line above
    # finds it. This is for the node that registered a laboratory and was then
    # rebuilt from the feed: the uuid is gone, but the pair the register is
    # keyed on is not, and matching on it is what stops the rebuild ending with
    # two rows for one laboratory.
    def adopt_local(model, entity_type, entry)
      return nil unless entity_type == "labs"
      return nil if entry[:source_code].blank?

      local = model.find_by(facility_code: entry[:facility_code], source_code: entry[:source_code])
      return nil if local.nil?

      local.uuid = entry[:uuid]
      local
    end

    def assign_extras(record, entity_type, entry)
      case entity_type
      when "indicators"
        record.unit = entry[:unit]
        record.value_type = entry[:value_type] if entry[:value_type].present?
      when "test_types"
        record.department = resolve("departments", entry.dig(:department, :national_code))
        record.target_tat = entry[:target_tat]
        record.performed_on_sex = entry[:performed_on_sex] if entry[:performed_on_sex].present?
      when "labs"
        record.assign_attributes(entry.slice(*LAB_ATTRIBUTES))
      when "facilities"
        record.assign_attributes(entry.slice(*FACILITY_ATTRIBUTES))
      end
    end

    # Ranges have no identity of their own, so the set is replaced when it
    # differs and left alone when it does not.
    def apply_ranges(record, entry)
      desired = Array(entry[:ranges]).map { |range| range.slice(*RANGE_KEYS) }
      existing = record.indicator_ranges.map { |range| range.slice(*RANGE_KEYS).symbolize_keys }

      return if normalise_ranges(existing) == normalise_ranges(desired)

      record.indicator_ranges.destroy_all
      desired.each { |attributes| record.indicator_ranges.create!(attributes) }
    end

    RANGE_KEYS = %i[age_min age_max sex range_lower range_upper interpretation value].freeze

    def normalise_ranges(ranges)
      ranges.map { |range| RANGE_KEYS.map { |key| range[key].to_s } }.sort
    end

    def apply_links(record, entity_type, entry)
      Dictionary.links_for(entity_type).each do |link|
        codes = Array(entry[link.name]).filter_map { |item| item[:national_code] }

        DictionaryLinkDeferral.forget_for(owner: record, link_name: link.name)

        target_ids = codes.filter_map do |code|
          target = resolve(link.target_entity, code)

          if target.nil?
            DictionaryLinkDeferral.remember!(owner: record, link_name: link.name, target_code: code)
            @deferred += 1
            next
          end

          target.id
        end

        reconcile(link, record.id, target_ids)
      end
    end

    def reconcile(link, owner_id, target_ids)
      join_model = link.join_model
      existing = join_model.where(link.owner_key => owner_id).pluck(link.target_key)

      (target_ids - existing).each do |target_id|
        join_model.create!(link.owner_key => owner_id, link.target_key => target_id)
      end

      stale = existing - target_ids
      join_model.where(link.owner_key => owner_id, link.target_key => stale).destroy_all if stale.any?
    end

    # A link that arrived before the entry it points at. Retried after every
    # batch: on a first sync this is the normal case, not an error.
    def resolve_deferrals
      DictionaryLinkDeferral.find_each do |deferral|
        owner = deferral.owner
        next deferral.destroy! if owner.nil?

        link = Dictionary.links_for(deferral.owner_entity_type).find { |l| l.name.to_s == deferral.link_name }
        next deferral.destroy! if link.nil?

        target = resolve(link.target_entity, deferral.target_code)
        next if target.nil?

        unless link.join_model.exists?(link.owner_key => owner.id, link.target_key => target.id)
          # Creating the join bumps the owner through BumpsOwnerRevision. Put the
          # replicated number back: the owner's revision belongs to the national
          # node, not to this one.
          replicated_revision = owner.revision
          link.join_model.create!(link.owner_key => owner.id, link.target_key => target.id)
          owner.update_column(:revision, replicated_revision)
        end

        deferral.destroy!
        @resolved += 1
      end
    end

    def resolve(entity_type, national_code)
      return nil if national_code.blank?

      @resolved_cache ||= {}
      key = [ entity_type, national_code ]
      return @resolved_cache[key] if @resolved_cache.key?(key)

      @resolved_cache[key] = Dictionary.model_for!(entity_type).find_by(national_code: national_code)
    end
  end
end
