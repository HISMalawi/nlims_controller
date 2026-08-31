# frozen_string_literal: true

# Stands in for Dictionary::MlabSource so the importer can be tested, and later
# steps can be given a realistic dictionary, without a live mLab database.
#
# A snapshot is already a file answering the source methods, so this is one of
# those with the means to bend the data — dropping a row, changing a field,
# swapping a whole link table — the way a spec needs to watch the importer
# react.
class MlabFixtureSource < Dictionary::SnapshotSource
  DEFAULT_PATH = "spec/fixtures/mlab_sample.json"

  def describe = "fixture"

  # Drop rows so a spec can watch the importer retire what has gone away
  # upstream.
  def without(entity, id)
    self.class.new(@data.merge(entity => rows_of(entity).reject { |row| row[:id] == id }))
  end

  # Change a field so a spec can watch an update come through.
  def change(entity, id, attributes)
    updated = rows_of(entity).map { |row| row[:id] == id ? row.merge(attributes) : row }
    self.class.new(@data.merge(entity => updated))
  end

  # Swap a whole collection, for link tables where rows have no id of their own.
  def replace(entity, rows)
    self.class.new(@data.merge(entity => rows))
  end

  private

  def rows_of(entity)
    Array(@data[entity.to_sym]).map(&:dup)
  end
end
