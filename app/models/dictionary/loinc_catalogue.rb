# frozen_string_literal: true

require "csv"

module Dictionary
  # LOINC's own release table, read from the `Loinc.csv` a deployment downloads
  # from loinc.org.
  #
  # Not vendored, and not optional to obtain: the LOINC release carries its own
  # licence and is not ours to redistribute inside this repository. Every task
  # that needs it takes a path, and says so plainly when the file is not there.
  #
  # Only the columns curation actually uses are kept. The full release is a
  # hundred thousand rows and forty-odd columns, and holding all of it to answer
  # "does this code exist and what is it called" would cost a few hundred
  # megabytes for nothing.
  class LoincCatalogue
    class MissingFile < StandardError; end

    ACTIVE = "ACTIVE"
    DEPRECATED = "DEPRECATED"

    Entry = Struct.new(:code, :long_name, :short_name, :component, :system, :status, :entry_class,
                       keyword_init: true) do
      def active? = status.nil? || status.casecmp(ACTIVE).zero?
      def deprecated? = status.to_s.casecmp(DEPRECATED).zero?

      # What a curator reads when deciding. The long common name is the one
      # written for humans; the others are fallbacks for rows that lack it.
      def label = long_name.presence || short_name.presence || component.to_s
    end

    # The release has changed column names over the years, so each field is
    # looked for under every spelling it has had rather than assuming one.
    COLUMNS = {
      code: %w[LOINC_NUM LOINC LoincNumber],
      long_name: %w[LONG_COMMON_NAME LongCommonName],
      short_name: %w[SHORTNAME ShortName],
      component: %w[COMPONENT Component],
      system: %w[SYSTEM System],
      status: %w[STATUS Status],
      entry_class: %w[CLASS Class]
    }.freeze

    attr_reader :path

    def self.from_path(path)
      raise MissingFile, "no LOINC release at #{path}" if path.blank? || !File.exist?(path)

      new(path)
    end

    def initialize(path)
      @path = path.to_s
    end

    def entries
      @entries ||= load
    end

    def size = entries.size

    def fetch(code)
      entries[code.to_s.strip]
    end

    def include?(code)
      entries.key?(code.to_s.strip)
    end

    # Codes matching every one of the given tokens, best first. The index is
    # built once and shared by every lookup, because suggesting candidates for
    # a hundred test types otherwise means a hundred passes over the release.
    def search(tokens, limit: 3)
      tokens = Array(tokens).map(&:downcase).uniq.reject { |token| token.length < 3 }
      return [] if tokens.empty?

      candidates = tokens.filter_map { |token| index[token] }
      return [] if candidates.empty?

      candidates.reduce(:&).to_a
                .map { |code| [ entries[code], score(entries[code], tokens) ] }
                .reject { |entry, _| entry.deprecated? }
                .sort_by { |entry, points| [ -points, entry.label.length ] }
                .first(limit)
                .map(&:first)
    end

    private

    def load
      table = {}

      CSV.foreach(@path, headers: true, encoding: "bom|utf-8") do |row|
        code = value(row, :code)
        next if code.blank?

        table[code] = Entry.new(
          code: code,
          long_name: value(row, :long_name),
          short_name: value(row, :short_name),
          component: value(row, :component),
          system: value(row, :system),
          status: value(row, :status),
          entry_class: value(row, :entry_class)
        )
      end

      table
    end

    def value(row, field)
      COLUMNS.fetch(field).each do |header|
        found = row[header]
        return found.strip if found.present?
      end

      nil
    end

    def index
      @index ||= entries.each_with_object({}) do |(code, entry), table|
        tokenise(entry.label).each do |token|
          (table[token] ||= Set.new) << code
        end
      end
    end

    # A tighter match on more of the name scores higher. Deliberately crude:
    # this only decides the order in which a person is shown three candidates,
    # and pretending to more precision than that would invite them to accept the
    # first row without reading it.
    def score(entry, tokens)
      label_tokens = tokenise(entry.label)
      overlap = (label_tokens & tokens).length

      overlap.to_f / [ label_tokens.length, 1 ].max
    end

    def tokenise(text)
      text.to_s.downcase.split(/[^a-z0-9]+/).reject { |token| token.length < 3 }.uniq
    end
  end
end
