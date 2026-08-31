# frozen_string_literal: true

require "rails_helper"

# The one property the whole replication design rests on: a local node that
# advances its cursor can never step over a change that had not committed yet.
#
# These examples need real concurrent connections, so they run without the
# surrounding test transaction and clean up after themselves.
RSpec.describe "dictionary replication cursor", type: :model do
  self.use_transactional_tests = false

  after do
    TestTypeSpecimenType.delete_all
    TestType.delete_all
    SpecimenType.delete_all
    Sequence.update_all(value: 0)
  end

  def in_new_connection(&block)
    ActiveRecord::Base.connection_pool.with_connection(&block)
  end

  def create_published(name = "Teste #{SecureRandom.hex(4)}")
    TestType.transaction { TestType.create!(name: name, status: DictionaryEntry::ACTIVE) }
  end

  # Outside a transaction the lock is released the moment the number is read, so
  # two writers could commit in the opposite order to their numbers. That is the
  # hole the sequence exists to close, so taking a number that way is refused.
  it "refuses to hand out a revision outside a transaction" do
    expect { Sequence.next_revision! }
      .to raise_error(Sequence::NotInTransaction, /must run inside a transaction/)
  end

  describe "revision order" do
    # A counter that is not locked until commit — an AUTO_INCREMENT id, a
    # max(revision) + 1, or updated_at — lets a slow writer take a low number
    # and commit after a fast writer that took a high one. Sorting by that
    # number would then disagree with the order the rows became visible, and a
    # cursor past the high number would never come back for the low one.
    # Deliberately updates records that already exist. Creating would also take
    # the national code sequence, and that lock alone would serialise the
    # writers — the example would then pass even with a revision counter that
    # has no lock at all.
    it "matches commit order even when writers hold their transactions open for different lengths" do
      records = Array.new(3) { create_published }
      pauses = [ 0.25, 0.05, 0.15 ]

      threads = records.zip(pauses).map do |record, pause|
        Thread.new do
          in_new_connection do
            TestType.transaction do
              TestType.find(record.id).update!(short_name: "alterado")
              sleep(pause)
            end

            {
              revision: TestType.find(record.id).revision,
              committed_at: Process.clock_gettime(Process::CLOCK_MONOTONIC)
            }
          end
        end
      end

      results = threads.map(&:value)

      by_revision = results.sort_by { |result| result[:revision] }
      by_commit = results.sort_by { |result| result[:committed_at] }

      expect(by_revision).to eq(by_commit)
    end

    it "never hands the same number to two writers" do
      records = Array.new(3) { create_published }

      threads = records.map do |record|
        Thread.new do
          in_new_connection do
            TestType.transaction do
              found = TestType.find(record.id)
              found.update!(short_name: "alterado")
              found.revision
            end
          end
        end
      end

      revisions = threads.map(&:value)

      expect(revisions.uniq.length).to eq(revisions.length)
    end
  end

  describe "a node pulling while the dictionary is being written" do
    it "sees every published change exactly once" do
      per_writer = 3
      backlog = Array.new(3) { Array.new(per_writer) { create_published } }

      # Start from where a caught-up node would be, so only the concurrent
      # updates below are in play.
      cursor = Dictionary.cursor

      writers = backlog.map do |records|
        Thread.new do
          in_new_connection do
            records.map do |record|
              TestType.transaction do
                found = TestType.find(record.id)
                found.update!(short_name: "alterado")
                sleep(rand * 0.05)
                found.uuid
              end
            end
          end
        end
      end

      seen = []
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 20

      # Poll the way a local node does: take what is past the cursor, then move
      # the cursor to the highest revision actually received.
      loop do
        batch = Dictionary.changes_since(cursor, entities: %w[test_types])
        batch.each { |(_, record)| seen << record.uuid }
        cursor = batch.last.last.revision if batch.any?

        break if batch.empty? && writers.none?(&:alive?)
        raise "polling never drained (saw #{seen.length})" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        sleep(0.01)
      end

      # `value` rather than `join`, so a writer that blew up fails the example
      # instead of quietly reducing the expected count.
      written = writers.flat_map(&:value)

      expect(seen.uniq.length).to eq(seen.length), "the same change was delivered twice"
      expect(seen.sort).to eq(written.sort)
    end
  end

  describe "what the cursor exposes" do
    it "reports where a fully caught up node would be" do
      test_type = nil
      TestType.transaction { test_type = TestType.create!(name: "Actual", status: DictionaryEntry::ACTIVE) }

      expect(Dictionary.cursor).to eq(test_type.revision)
      expect(Dictionary.changes_since(Dictionary.cursor)).to be_empty
    end

    # A draft still consumes a revision, so the cursor can be ahead of anything
    # a node has been given. That is fine: the cursor is a watermark, not a
    # count of deliverable rows.
    it "moves for a draft without delivering it" do
      TestType.transaction { TestType.create!(name: "Rascunho", status: DictionaryEntry::DRAFT) }

      expect(Dictionary.cursor).to be_positive
      expect(Dictionary.changes_since(0)).to be_empty
    end
  end
end
