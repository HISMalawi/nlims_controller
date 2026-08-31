# frozen_string_literal: true

require "csv"

module Dictionary
  # What is wrong with the dictionary as it stands. Runs after an import and
  # before anyone promotes anything, because the mLab data has accumulated
  # fifteen years of duplicates, half-entered tests and indicators attached to
  # nothing, and promoting those makes them national.
  #
  # Nothing here blocks an import. The point is a list a laboratory person can
  # work through, not a gate.
  class QualityReport
    Issue = Struct.new(:issue, :entity_type, :national_code, :name, :detail, keyword_init: true) do
      def to_row = [ issue, entity_type, national_code, name, detail ]
    end

    HEADERS = %w[issue entity_type national_code name detail].freeze
    DEFAULT_PATH = "tmp/dictionary_quality.csv"

    def rows
      @rows ||= [
        duplicate_names,
        test_types_without_indicators,
        test_types_without_specimen_types,
        test_types_without_department,
        indicators_without_test_type,
        numeric_indicators_without_ranges,
        invalid_ranges,
        specimen_types_without_test_types,
        drugs_without_organisms,
        organisms_without_test_types,
        panels_without_test_types
      ].flatten
    end

    def counts
      rows.group_by(&:issue).transform_values(&:length).sort_by { |_, count| -count }.to_h
    end

    def write_csv(path = DEFAULT_PATH)
      full_path = Rails.root.join(path)
      FileUtils.mkdir_p(File.dirname(full_path))

      CSV.open(full_path, "w") do |csv|
        csv << HEADERS
        rows.each { |issue| csv << issue.to_row }
      end

      full_path
    end

    private

    # Two entries with the same name are the commonest way a laboratory ends up
    # ordering the wrong test, and mLab has no constraint against it.
    def duplicate_names
      Dictionary.models.flat_map do |model|
        model.all.group_by { |entry| normalise(entry.name) }
             .select { |_, entries| entries.length > 1 }
             .flat_map do |_, entries|
               others = entries.map(&:national_code)
               entries.map do |entry|
                 issue_for(entry, "duplicate_name",
                           "mesmo nome que #{(others - [ entry.national_code ]).join(', ')}")
               end
             end
      end
    end

    # A test that reports nothing cannot carry a result.
    def test_types_without_indicators
      TestType.where.missing(:test_type_indicators)
              .map { |entry| issue_for(entry, "test_type_without_indicators", "nenhum indicador associado") }
    end

    # A test with no specimen cannot be ordered: there is nothing to collect.
    def test_types_without_specimen_types
      TestType.where.missing(:test_type_specimen_types)
              .map { |entry| issue_for(entry, "test_type_without_specimen_types", "nenhum espécime associado") }
    end

    def test_types_without_department
      TestType.where(department_id: nil)
              .map { |entry| issue_for(entry, "test_type_without_department", "sem secção") }
    end

    def indicators_without_test_type
      Indicator.where.missing(:test_type_indicators)
               .map { |entry| issue_for(entry, "indicator_without_test_type", "não pertence a nenhum teste") }
    end

    # A numeric result with no reference interval cannot be interpreted.
    def numeric_indicators_without_ranges
      Indicator.where(value_type: "Numeric").where.missing(:indicator_ranges)
               .map { |entry| issue_for(entry, "numeric_indicator_without_range", "numérico sem intervalo") }
    end

    def invalid_ranges
      IndicatorRange.includes(:indicator).filter_map do |range|
        detail = range_problem(range)
        next unless detail

        issue_for(range.indicator, "invalid_range", detail)
      end
    end

    def range_problem(range)
      if range.range_lower && range.range_upper && range.range_lower > range.range_upper
        "intervalo invertido (#{range.range_lower} > #{range.range_upper})"
      elsif range.range_lower.nil? && range.range_upper.nil? && range.value.blank?
        "intervalo sem limites nem valor"
      elsif range.age_min && range.age_max && range.age_min > range.age_max
        "idades invertidas (#{range.age_min} > #{range.age_max})"
      end
    end

    def specimen_types_without_test_types
      SpecimenType.where.missing(:test_type_specimen_types)
                  .map { |entry| issue_for(entry, "specimen_type_without_test_types", "nenhum teste o usa") }
    end

    def drugs_without_organisms
      Drug.where.missing(:organism_drugs)
          .map { |entry| issue_for(entry, "drug_without_organisms", "nenhum organismo o testa") }
    end

    def organisms_without_test_types
      Organism.where.missing(:test_type_organisms)
              .map { |entry| issue_for(entry, "organism_without_test_types", "nenhum teste o isola") }
    end

    def panels_without_test_types
      TestPanel.where.missing(:test_panel_test_types)
               .map { |entry| issue_for(entry, "test_panel_without_test_types", "painel vazio") }
    end

    def issue_for(entry, issue, detail)
      Issue.new(issue: issue, entity_type: entry.class.entity_type,
                national_code: entry.national_code, name: entry.name, detail: detail)
    end

    def normalise(name)
      ActiveSupport::Inflector.transliterate(name.to_s).downcase.gsub(/\s+/, " ").strip
    end
  end
end
