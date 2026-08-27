# frozen_string_literal: true

module Dictionary
  # The mLab catalogue as it stood when it was taken, kept as a file.
  #
  # Answers the same methods as MlabSource and MlabApiSource, in the same
  # shapes, so MlabImporter reads a snapshot exactly as it reads mLab itself.
  # That is the point of it: a new national node has no mLab to reach — the
  # laboratories do — so it starts from the catalogue shipped with the release
  # and every test created afterwards is created on the national node by hand.
  #
  #   bin/rails dictionary:snapshot   # mLab -> db/dictionary/mlab_catalog.json
  #   bin/rails dictionary:seed       # that file -> this node's dictionary
  #
  # The file carries mLab's own rows, not ours: its ids, its column names, its
  # indicator type numbers. Translating on the way in is the importer's work,
  # and doing it here as well would leave two places to fix when mLab moves.
  class SnapshotSource
    class Missing < StandardError; end

    DEFAULT_PATH = "db/dictionary/mlab_catalog.json"

    # Everything a source answers, which is also everything a snapshot holds.
    ENTITIES = %i[
      departments specimen_types drugs organisms organism_drug_links
      indicators indicator_ranges test_types
      test_type_indicator_links test_type_specimen_links test_type_organism_links
      test_panels test_panel_test_type_links
    ].freeze

    def self.available?(path = self::DEFAULT_PATH)
      Rails.root.join(path).exist?
    end

    def self.load(path = self::DEFAULT_PATH)
      file = Rails.root.join(path)
      raise Missing, "There is no catalogue at #{path}. Take one with `rake dictionary:snapshot`." unless file.exist?

      new(JSON.parse(file.read, symbolize_names: true), path: path)
    end

    # Reads a live source once and writes what it answered. Kept here rather
    # than in the rake task so that what is written and what is read back are
    # the same list of names.
    def self.write(source, path = self::DEFAULT_PATH)
      file = Rails.root.join(path)
      FileUtils.mkdir_p(file.dirname)

      data = { meta: { taken_at: Time.current.iso8601, source: source.describe } }
      ENTITIES.each { |entity| data[entity] = source.public_send(entity) }

      file.write("#{JSON.pretty_generate(data)}\n")
      file
    end

    def initialize(data, path: nil)
      @data = data
      @path = path
    end

    def describe
      taken_at = @data.dig(:meta, :taken_at)

      [ @path || "catálogo", ("de #{taken_at}" if taken_at) ].compact.join(" ")
    end

    ENTITIES.each do |entity|
      define_method(entity) { rows(entity) }
    end

    # A snapshot taken from the database carries mLab's indicator type number; one
    # taken from the API carries the value type already worked out. Either way the
    # importer is handed the value type.
    def indicators
      rows(:indicators).map do |row|
        row[:value_type] ||= MlabSource::VALUE_TYPES.fetch(row[:test_indicator_type], "Free Text")
        row
      end
    end

    private

    def rows(name)
      Array(@data[name.to_sym]).map(&:dup)
    end
  end
end
