# frozen_string_literal: true

module Dictionary
  # Loads the dictionary from a SISLAB/mLab database into the national one.
  #
  # Re-runnable. Identity comes from ExternalMapping: the mLab id is kept as the
  # external code, so a second run finds what the first run created and updates
  # it instead of making a second copy. An entry whose mLab row has since been
  # retired is retired here too, rather than left behind as a national fact that
  # no longer exists anywhere.
  #
  # Everything arrives as a draft. Nothing reaches a local node until somebody
  # promotes it — see Dictionary::Promotion.
  class MlabImporter
    SYSTEM = "mlab"
    ACTOR = "importação mlab"

    # mLab writes the words out; we store the single letters the rest of the
    # system uses.
    SEXES = { "Both" => "Both", "Male" => "M", "Female" => "F" }.freeze

    attr_reader :entities, :links, :retired, :skipped

    def initialize(source:)
      @source = source
      @entities = {}
      @links = Hash.new(0)
      @retired = Hash.new(0)
      @skipped = []
      @uuid_of = {}
      @id_of = {}
      @seen = Hash.new { |hash, key| hash[key] = Set.new }
    end

    # One transaction: a half-imported dictionary is worse than none, and the
    # revision sequence is held throughout, so no other writer can interleave.
    def call
      ApplicationRecord.transaction do
        import_departments
        import_specimen_types
        import_drugs
        import_organisms
        import_indicators
        import_test_types
        import_test_panels
        retire_entries_absent_from_source
      end

      self
    end

    def summary
      lines = entities.map do |entity_type, counts|
        format("  %-16s %4d criados  %4d actualizados  %4d sem alteração  %3d retirados",
               entity_type, counts[:created], counts[:updated], counts[:unchanged], retired[entity_type].to_i)
      end

      lines += links.sort.map { |label, count| format("  %-16s %4d", label, count) }
      lines << format("  %-16s %4d", "ignorados", skipped.length) if skipped.any?
      lines.join("\n")
    end

    private

    # ---------- entities ----------

    def import_departments
      @source.departments.each do |row|
        upsert(Department, "departments", row, name: clean(row[:name]), moh_code: row[:code].presence)
      end
    end

    def import_specimen_types
      @source.specimen_types.each do |row|
        upsert(SpecimenType, "specimen_types", row,
               name: clean(row[:name]), description: clean(row[:description]))
      end
    end

    def import_drugs
      @source.drugs.each do |row|
        upsert(Drug, "drugs", row, name: clean(row[:name]), short_name: clean(row[:short_name]))
      end
    end

    def import_organisms
      @source.organisms.each do |row|
        upsert(Organism, "organisms", row, name: clean(row[:name]), description: clean(row[:description]))
      end

      reconcile_links(
        join_model: OrganismDrug,
        owner_column: :organism_id,
        target_column: :drug_id,
        label: "organismo/fármaco",
        desired: desired_links(@source.organism_drug_links, "organisms", :organism_id, "drugs", :drug_id)
      )
    end

    def import_indicators
      @source.indicators.each do |row|
        next if skip(row, "indicators", "sem nome")

        upsert(Indicator, "indicators", row,
               name: clean(row[:name]),
               unit: clean(row[:unit]),
               description: clean(row[:description]),
               value_type: row[:value_type])
      end

      import_indicator_ranges
    end

    def import_indicator_ranges
      by_indicator = @source.indicator_ranges.group_by { |row| row[:test_indicator_id] }

      @seen["indicators"].each do |external_code|
        indicator_id = @id_of[[ "indicators", external_code ]]
        next unless indicator_id

        desired = (by_indicator[external_code.to_i] || []).map { |row| range_attributes(row) }
        replace_ranges(indicator_id, desired)
      end
    end

    def range_attributes(row)
      {
        age_min: row[:min_age],
        age_max: row[:max_age],
        sex: SEXES.fetch(row[:sex].to_s, "Both"),
        range_lower: row[:lower_range],
        range_upper: row[:upper_range],
        interpretation: clean(row[:interpretation]),
        value: clean(row[:value])
      }
    end

    # Ranges have no identity of their own in mLab worth preserving, so the set
    # is compared as a whole and only rewritten when it actually differs. That
    # keeps a re-run from bumping every indicator's revision.
    def replace_ranges(indicator_id, desired)
      existing = IndicatorRange.where(indicator_id: indicator_id).map { |range| range_attributes_of(range) }
      return if existing.map { |attributes| range_key(attributes) }.sort ==
                desired.map { |attributes| range_key(attributes) }.sort

      IndicatorRange.where(indicator_id: indicator_id).destroy_all
      desired.each do |attributes|
        IndicatorRange.create!(attributes.merge(indicator_id: indicator_id))
        @links["intervalos"] += 1
      end
    end

    # A comparable, engine-independent shape for one range. Decimals are pinned
    # to four places because mLab's column precision differs from ours, and
    # comparing the raw values would rewrite every range on every run.
    def range_key(attributes)
      [
        attributes[:age_min].to_s,
        attributes[:age_max].to_s,
        attributes[:sex].to_s,
        decimal_key(attributes[:range_lower]),
        decimal_key(attributes[:range_upper]),
        attributes[:interpretation].to_s,
        attributes[:value].to_s
      ]
    end

    def decimal_key(value)
      return "" if value.nil?

      BigDecimal(value.to_s).round(4).to_s("F")
    end

    def range_attributes_of(range)
      {
        age_min: range.age_min,
        age_max: range.age_max,
        sex: range.sex,
        range_lower: range.range_lower,
        range_upper: range.range_upper,
        interpretation: range.interpretation,
        value: range.value
      }
    end

    def import_test_types
      @source.test_types.each do |row|
        department_id = @id_of[[ "departments", row[:department_id].to_s ]]

        upsert(TestType, "test_types", row,
               name: clean(row[:name]),
               short_name: clean(row[:short_name]),
               department_id: department_id,
               target_tat: clean(row[:target_tat]),
               performed_on_sex: SEXES.fetch(row[:sex].to_s, "Both"))
      end

      reconcile_links(
        join_model: TestTypeSpecimenType,
        owner_column: :test_type_id,
        target_column: :specimen_type_id,
        label: "teste/espécime",
        desired: desired_links(@source.test_type_specimen_links, "test_types", :test_type_id,
                               "specimen_types", :specimen_type_id)
      )

      reconcile_links(
        join_model: TestTypeIndicator,
        owner_column: :test_type_id,
        target_column: :indicator_id,
        label: "teste/indicador",
        desired: desired_links(@source.test_type_indicator_links, "test_types", :test_type_id,
                               "indicators", :indicator_id)
      )

      reconcile_links(
        join_model: TestTypeOrganism,
        owner_column: :test_type_id,
        target_column: :organism_id,
        label: "teste/organismo",
        desired: desired_links(@source.test_type_organism_links, "test_types", :test_type_id,
                               "organisms", :organism_id)
      )
    end

    def import_test_panels
      @source.test_panels.each do |row|
        upsert(TestPanel, "test_panels", row,
               name: clean(row[:name]), short_name: clean(row[:short_name]),
               description: clean(row[:description]))
      end

      reconcile_links(
        join_model: TestPanelTestType,
        owner_column: :test_panel_id,
        target_column: :test_type_id,
        label: "painel/teste",
        desired: desired_links(@source.test_panel_test_type_links, "test_panels", :test_panel_id,
                               "test_types", :test_type_id)
      )
    end

    # ---------- machinery ----------

    def upsert(model, entity_type, row, attributes)
      external_code = row[:id].to_s
      @seen[entity_type] << external_code

      record = existing_record(model, entity_type, external_code)

      if record
        record.assign_attributes(attributes)

        if record.changed?
          record.save!
          bump(entity_type, :updated)
        else
          bump(entity_type, :unchanged)
        end
      else
        record = model.create!(attributes.merge(status: DictionaryEntry::DRAFT, status_actor: ACTOR))
        ExternalMapping.create!(system: SYSTEM, entity_type: entity_type, entity_uuid: record.uuid,
                                external_code: external_code, external_name: row[:name])
        bump(entity_type, :created)
      end

      @uuid_of[[ entity_type, external_code ]] = record.uuid
      @id_of[[ entity_type, external_code ]] = record.id
      record
    end

    def existing_record(model, entity_type, external_code)
      uuid = ExternalMapping.resolve(system: SYSTEM, entity_type: entity_type, external_code: external_code)
      uuid && model.find_by(uuid: uuid)
    end

    # Translates a list of mLab id pairs into our own ids. Owners with no links
    # are included with an empty list, so a link removed upstream is removed here.
    def desired_links(rows, owner_entity, owner_key, target_entity, target_key)
      desired = @seen[owner_entity].each_with_object({}) do |external_code, hash|
        id = @id_of[[ owner_entity, external_code ]]
        hash[id] = [] if id
      end

      rows.each do |row|
        owner_id = @id_of[[ owner_entity, row[owner_key].to_s ]]
        target_id = @id_of[[ target_entity, row[target_key].to_s ]]
        next unless owner_id && target_id

        desired[owner_id] ||= []
        desired[owner_id] << target_id
      end

      desired.transform_values(&:uniq)
    end

    def reconcile_links(join_model:, owner_column:, target_column:, desired:, label:)
      desired.each do |owner_id, target_ids|
        existing = join_model.where(owner_column => owner_id).pluck(target_column)

        (target_ids - existing).each do |target_id|
          join_model.create!(owner_column => owner_id, target_column => target_id)
          @links[label] += 1
        end

        stale = existing - target_ids
        next if stale.empty?

        join_model.where(owner_column => owner_id, target_column => stale).destroy_all
        @links["#{label} (removidos)"] += stale.length
      end
    end

    # An entry mapped from mLab whose row is gone or retired upstream. It cannot
    # simply be deleted: a local node may already hold it, and only a retirement
    # travels down the delta.
    def retire_entries_absent_from_source
      Dictionary::ENTITIES.each_key do |entity_type|
        model = Dictionary.model_for!(entity_type)

        ExternalMapping.where(system: SYSTEM, entity_type: entity_type)
                       .where.not(external_code: @seen[entity_type].to_a)
                       .find_each do |mapping|
          entry = model.find_by(uuid: mapping.entity_uuid)
          next if entry.nil? || entry.retired?

          entry.retire!(actor: ACTOR, reason: "já não existe na fonte mLab")
          @retired[entity_type] += 1
        end
      end
    end

    def skip(row, entity_type, reason)
      return false if clean(row[:name]).present?

      @skipped << { entity_type: entity_type, external_code: row[:id], reason: reason }
      true
    end

    def bump(entity_type, key)
      @entities[entity_type] ||= { created: 0, updated: 0, unchanged: 0 }
      @entities[entity_type][key] += 1
    end

    def clean(value)
      value.to_s.strip.presence
    end
  end
end
