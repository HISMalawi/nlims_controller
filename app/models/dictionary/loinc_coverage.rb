# frozen_string_literal: true

require "csv"

module Dictionary
  # How much of the dictionary carries a LOINC code.
  #
  # A single number, per entity type, because that is what turns "we should
  # curate these one day" into a task with an end. The catalogue was imported at
  # zero, and every screen and report that mentions LOINC states the same figure
  # so that nobody has to take anyone's word for where it stands.
  #
  # Only active entries count. A draft has not been published to anybody and a
  # retired one is on its way out; holding either against the total would move
  # the percentage for reasons that have nothing to do with curation.
  class LoincCoverage
    Row = Struct.new(:entity_type, :total, :covered, keyword_init: true) do
      def missing = total - covered

      def percentage
        return nil if total.zero?

        ((covered / total.to_f) * 100).round
      end

      def to_row = [ entity_type, total, covered, missing, percentage ]
    end

    HEADERS = %w[entity_type active covered missing percentage].freeze
    UNCOVERED_HEADERS = %w[entity_type national_code name loinc_code].freeze
    DEFAULT_PATH = "tmp/loinc_coverage.csv"

    def rows
      @rows ||= Loinc::CURATED_ENTITIES.map do |entity_type|
        model = Dictionary.model_for!(entity_type)
        active = model.active

        Row.new(entity_type: entity_type, total: active.count,
                covered: active.where.not(loinc_code: nil).count)
      end
    end

    def total = rows.sum(&:total)
    def covered = rows.sum(&:covered)
    def missing = total - covered

    def percentage
      return nil if total.zero?

      ((covered / total.to_f) * 100).round
    end

    # Every active entry still without a code, which is the worklist itself.
    # `loinc_code` is emitted empty on purpose: this file is the one a curator
    # fills in and hands back to `dictionary:loinc:apply`.
    def uncovered
      Loinc::CURATED_ENTITIES.flat_map do |entity_type|
        Dictionary.model_for!(entity_type)
                  .active.where(loinc_code: nil).order(:name)
                  .map { |entry| [ entity_type, entry ] }
      end
    end

    def write_csv(path = DEFAULT_PATH)
      full_path = Rails.root.join(path)
      FileUtils.mkdir_p(File.dirname(full_path))

      CSV.open(full_path, "w") do |csv|
        csv << HEADERS
        rows.each { |row| csv << row.to_row }
        csv << [ "total", total, covered, missing, percentage ]
      end

      full_path
    end

    def summary
      lines = rows.map do |row|
        format("  %-16s %5d activos  %5d com LOINC  %5d sem  %s",
               row.entity_type, row.total, row.covered, row.missing,
               row.percentage ? "#{row.percentage}%" : "—")
      end

      lines.join("\n")
    end
  end
end
