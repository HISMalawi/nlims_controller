# frozen_string_literal: true

# Stands in for Dictionary::MlabSource so the importer can be tested, and later
# steps can be given a realistic dictionary, without a live mLab database.
#
# Answers the same methods with the same shapes. The indicator value_type
# mapping is taken from the real source, so that translation stays tested in one
# place.
class MlabFixtureSource
  DEFAULT_PATH = "spec/fixtures/mlab_sample.json"

  ENTITY_METHODS = %i[
    departments specimen_types drugs organisms organism_drug_links
    indicators indicator_ranges test_types
    test_type_indicator_links test_type_specimen_links test_type_organism_links
    test_panels test_panel_test_type_links
  ].freeze

  def self.load(path = DEFAULT_PATH)
    new(JSON.parse(Rails.root.join(path).read, symbolize_names: true))
  end

  def initialize(data)
    @data = data
  end

  def describe = "fixture"

  ENTITY_METHODS.each do |name|
    define_method(name) { rows(name) }
  end

  def indicators
    rows(:indicators).map do |row|
      row.merge(value_type: Dictionary::MlabSource::VALUE_TYPES.fetch(row[:test_indicator_type], "Free Text"))
    end
  end

  # Drop rows so a spec can watch the importer retire what has gone away
  # upstream.
  def without(entity, id)
    self.class.new(@data.merge(entity => rows(entity).reject { |row| row[:id] == id }))
  end

  # Change a field so a spec can watch an update come through.
  def change(entity, id, attributes)
    updated = rows(entity).map { |row| row[:id] == id ? row.merge(attributes) : row }
    self.class.new(@data.merge(entity => updated))
  end

  # Swap a whole collection, for link tables where rows have no id of their own.
  def replace(entity, rows)
    self.class.new(@data.merge(entity => rows))
  end

  private

  def rows(name)
    Array(@data[name.to_sym]).map(&:dup)
  end
end
