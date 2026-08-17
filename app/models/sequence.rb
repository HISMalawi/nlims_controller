# frozen_string_literal: true

# A named counter whose increment orders the callers by commit.
#
# This is what makes the replication cursor safe. `updated_at` cannot do the
# job: two transactions can write timestamps in one order and become visible in
# another, so a puller that advanced its cursor past the faster one would never
# see the slower one again. An AUTO_INCREMENT id has exactly the same hole.
#
# The UPDATE below takes an exclusive row lock that MySQL holds until the
# transaction commits. A second transaction therefore cannot obtain a number
# until the first has committed, which makes number order and commit order the
# same order. That is the whole guarantee, and spec/models/dictionary/cursor_spec
# is what proves it.
class Sequence < ApplicationRecord
  class NotInTransaction < StandardError; end

  DICTIONARY_REVISION = "dictionary_revision"

  def self.next!(name)
    unless connection.transaction_open?
      raise NotInTransaction,
            "Sequence.next!(#{name.inspect}) must run inside a transaction, otherwise the lock is released " \
            "before the change it numbers is committed and the ordering guarantee is lost"
    end

    ensure_row(name)

    # SELECT ... FOR UPDATE. A locking read always sees the latest committed
    # row, and the lock it takes is held until this transaction commits. An
    # UPDATE ... WHERE name = ? would look equivalent but MariaDB raises
    # "Record has changed since last read" when the row moved under a secondary
    # index, so the lock is taken explicitly and the write goes by primary key.
    row = lock.find_by!(name: name)
    row.update_column(:value, row.value + 1)
    row.value
  end

  def self.next_revision!
    next!(DICTIONARY_REVISION)
  end

  def self.current(name)
    where(name: name).pick(:value) || 0
  end

  # Keeps a local node's counter in step with the revisions it has been given,
  # so Dictionary.cursor means the same thing in both modes and a local node
  # could never allocate a number the national one has already used.
  def self.ensure_at_least!(name, value)
    return if value.to_i <= current(name)

    transaction do
      row = lock.find_by!(name: name)
      row.update_column(:value, value) if row.value < value.to_i
    end
  end

  def self.ensure_row(name)
    return if exists?(name: name)

    create!(name: name, value: 0)
  rescue ActiveRecord::RecordNotUnique
    nil
  end
  private_class_method :ensure_row
end
