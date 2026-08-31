# frozen_string_literal: true

require "csv"

module Dictionary
  # Applies a curator's decisions: a CSV of `entity_type, national_code,
  # loinc_code`, which is the worksheet LoincSuggestions writes once somebody
  # has filled the fourth column in.
  #
  # Every row is checked before any row is written. A file with one bad code in
  # it changes nothing at all, because a half-applied mapping leaves the curator
  # with no way of knowing where they got to, and the second run then skips the
  # rows that already worked and hides what was wrong with the rest.
  #
  # Each accepted code moves the entry's revision, so the change travels down
  # the delta to every laboratory exactly like any other dictionary change.
  class LoincMapping
    Outcome = Struct.new(:line, :entity_type, :national_code, :loinc_code, :result, :detail, keyword_init: true) do
      def ok? = %i[applied unchanged].include?(result)
      def to_row = [ line, entity_type, national_code, loinc_code, result, detail ]
    end

    HEADERS = %w[line entity_type national_code loinc_code result detail].freeze
    REQUIRED_COLUMNS = %w[entity_type national_code loinc_code].freeze

    class InvalidFile < StandardError; end

    attr_reader :outcomes

    # `catalogue` is optional but strongly wanted: without it a code can only be
    # checked for shape and check digit, and a well-formed code for a test that
    # does not exist passes. Runs that have one refuse anything LOINC does not
    # publish, or has withdrawn.
    def initialize(path:, actor:, catalogue: nil, dry_run: false)
      @path = path.to_s
      @actor = actor
      @catalogue = catalogue
      @dry_run = dry_run
      @outcomes = []
    end

    def call
      rows = read

      @outcomes = rows.map { |line, row| examine(line, row) }
      return self if failed? || @dry_run

      ApplicationRecord.transaction do
        @outcomes.select { |outcome| outcome.result == :applied }.each { |outcome| apply(outcome) }
      end

      self
    end

    def failed?
      @outcomes.any? { |outcome| !outcome.ok? }
    end

    def applied = @outcomes.count { |outcome| outcome.result == :applied }
    def unchanged = @outcomes.count { |outcome| outcome.result == :unchanged }
    def rejected = @outcomes.reject(&:ok?)

    def summary
      if @outcomes.empty?
        "  nada no ficheiro"
      elsif failed?
        "  #{rejected.length} linhas recusadas — nada foi aplicado"
      elsif @dry_run
        "  #{applied} por aplicar, #{unchanged} sem alteração (simulação)"
      else
        "  #{applied} aplicados, #{unchanged} sem alteração"
      end
    end

    def write_csv(path = "tmp/loinc_mapping_result.csv")
      full_path = Rails.root.join(path)
      FileUtils.mkdir_p(File.dirname(full_path))

      CSV.open(full_path, "w") do |csv|
        csv << HEADERS + %w[actor at]
        stamp = [ @actor, Time.current.iso8601 ]
        @outcomes.each { |outcome| csv << (outcome.to_row + stamp) }
      end

      full_path
    end

    private

    def read
      raise InvalidFile, "no mapping file at #{@path}" unless File.exist?(@path)

      table = CSV.read(@path, headers: true, encoding: "bom|utf-8")
      missing = REQUIRED_COLUMNS - (table.headers.compact.map(&:strip))

      raise InvalidFile, "the mapping file needs these columns: #{missing.join(', ')}" if missing.any?

      # Rows the curator left blank are not decisions and are not failures: a
      # worksheet is handed back with most of it still empty on the first pass.
      table.each_with_index.filter_map do |row, index|
        next if row["loinc_code"].to_s.strip.blank?

        [ index + 2, row ]
      end
    end

    def examine(line, row)
      entity_type = row["entity_type"].to_s.strip
      national_code = row["national_code"].to_s.strip
      loinc_code = row["loinc_code"].to_s.strip

      outcome = ->(result, detail = nil) do
        Outcome.new(line: line, entity_type: entity_type, national_code: national_code,
                    loinc_code: loinc_code, result: result, detail: detail)
      end

      return outcome.call(:not_curated, "#{entity_type} não é uma entidade curada") unless Loinc.curated?(entity_type)
      return outcome.call(:invalid_code, "#{loinc_code} não tem a forma de um código LOINC") unless
        Loinc.valid_code?(loinc_code)
      return outcome.call(:invalid_code, "#{loinc_code} tem o dígito de controlo errado") unless
        Loinc.check_digit_valid?(loinc_code)

      if @catalogue
        entry = @catalogue.fetch(loinc_code)
        return outcome.call(:unknown_code, "#{loinc_code} não existe na versão LOINC carregada") if entry.nil?
        return outcome.call(:deprecated_code, "#{loinc_code} foi retirado pelo LOINC") if entry.deprecated?
      end

      record = Dictionary.model_for!(entity_type).find_by(national_code: national_code)
      return outcome.call(:not_found, "#{national_code} não existe neste nó") if record.nil?
      return outcome.call(:unchanged, "já tinha #{loinc_code}") if record.loinc_code == loinc_code

      # Overwriting a code somebody curated earlier is a decision, not a typo to
      # be absorbed silently, so it is reported as one.
      detail = record.loinc_code.present? ? "substitui #{record.loinc_code}" : nil
      outcome.call(:applied, detail)
    end

    # The revision bump is what makes the change travel. Who made it is not
    # recorded against the entry: dictionary_status_changes is one row per
    # publication transition and its to_status is NOT NULL, so writing a
    # curation there would be a lie about what happened. The run's own result
    # file, which carries the actor, is the record until that table grows a
    # notion of an edit.
    def apply(outcome)
      record = Dictionary.model_for!(outcome.entity_type).find_by!(national_code: outcome.national_code)
      record.update!(loinc_code: outcome.loinc_code)
    end
  end
end
