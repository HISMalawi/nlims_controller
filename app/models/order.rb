# frozen_string_literal: true

# One sample submitted for testing. Replaces the old `specimen` table.
class Order < ApplicationRecord
  include HasUuid
  include DictionaryTerms
  include TracksStatus

  REQUESTED = "requested"
  ACCEPTED = "accepted"
  SPECIMEN_COLLECTED = "specimen_collected"
  IN_PROGRESS = "in_progress"
  REFERRED_OUT = "referred_out"
  REFERRED_IN = "referred_in"
  COMPLETED = "completed"
  REJECTED = "rejected"
  CANCELLED = "cancelled"

  # referred_out leads to completed because the result comes back under this
  # same tracking number, whichever laboratory produced it — and to rejected,
  # because the laboratory it was sent to may refuse the sample.
  #
  # referred_in is where a sample begins on the node that receives it. Nothing
  # transitions into it: the order is born that way, out of the referral its
  # origin dispatched.
  self.status_machine = StatusMachine.new(
    initial: REQUESTED,
    transitions: {
      REQUESTED => [ ACCEPTED, CANCELLED ],
      ACCEPTED => [ SPECIMEN_COLLECTED, REJECTED ],
      SPECIMEN_COLLECTED => [ IN_PROGRESS ],
      IN_PROGRESS => [ COMPLETED, REFERRED_OUT ],
      REFERRED_OUT => [ COMPLETED, REJECTED ],
      REFERRED_IN => [ ACCEPTED, REJECTED ]
    }
  )

  PRIORITIES = %w[routine urgent stat].freeze

  class AlreadyClaimed < StandardError; end

  belongs_to :patient
  belongs_to :source_client, class_name: "ApiClient", optional: true

  dictionary_term :specimen_type, entity: "specimen_types", name: :specimen_name, code: :specimen_code
  dictionary_term :rejection_reason, entity: "rejection_reasons", name: :rejection_name, code: :rejection_code

  has_many :order_tests, dependent: :destroy
  has_many :test_results, through: :order_tests
  has_many :referrals, dependent: :destroy

  validates :tracking_number, presence: true
  validates :receiving_facility_code, presence: true
  validates :priority, inclusion: { in: PRIORITIES }

  # Runs inside the transaction Active Record opens around the save, which is
  # what the sequence needs: the counter's lock has to be held until the row
  # that uses the number is committed.
  before_validation :assign_tracking_number, on: :create
  before_save :assign_revision

  scope :for_lab, ->(lab_code) { where(receiving_lab_code: lab_code) }
  # The unit that received the sample — this node. Not the unit that raised it:
  # that is `sending_facility_code`, and it is what the EMR feed is scoped by
  # (`TestResult.for_facility`). The two are the same on the node that took the
  # sample and different on the one it was referred to, which is the whole point
  # of keeping both.
  scope :for_facility, ->(facility_code) { where(receiving_facility_code: facility_code) }
  scope :open, -> { where.not(status: [ COMPLETED, REJECTED, CANCELLED ]) }
  scope :unclaimed, -> { where(claimed_at: nil) }

  # Raised at the unit and not yet taken by any of its laboratories. This is
  # what an mLab bench polls: a clinician asks the unit for a test, and which
  # laboratory runs it is settled by whichever one claims it.
  scope :unassigned, -> { where(receiving_lab_code: nil) }

  # What a laboratory polls for. Everything that changed, not only what is still
  # open: an order cancelled at the clinic after the laboratory took it is
  # precisely what that laboratory has to be told about.
  scope :changed_since, lambda { |cursor|
    where(revision: ((cursor.to_i + 1)..)).order(:revision, :id)
  }

  def self.find_by_tracking_number!(tracking_number)
    find_by!(tracking_number: tracking_number)
  end

  # Where a laboratory that has seen everything would leave its cursor.
  def self.cursor
    Sequence.current(Sequence::ORDER_REVISION)
  end

  def claimed?
    claimed_at.present?
  end

  # One laboratory takes the sample, and the second one to ask is told so.
  #
  # The conditional update is the whole mechanism: reading the column and then
  # writing it lets two laboratories both find it empty and both claim. MySQL
  # holds the row lock until this transaction commits, so the loser's update
  # matches no rows and it learns it lost rather than quietly overwriting.
  #
  # Taking the work is also accepting it, so the claim moves the status too, and
  # the history gets the entry an operator would look for.
  #
  # Claiming is also how an order raised by an EMR acquires its laboratory. It
  # arrived at the unit with none — the clinician asked the unit, not a bench —
  # and the bench that takes it is the one that will run it.
  def claim!(lab_code:, actor: nil)
    self.class.transaction do
      taken = self.class.unclaimed.where(id: id)
                  .update_all(claimed_at: Time.current, claimed_by_lab_code: lab_code,
                              receiving_lab_code: receiving_lab_code.presence || lab_code)

      raise AlreadyClaimed, "#{tracking_number} já foi reclamado por #{reload.claimed_by_lab_code}" if taken.zero?

      reload
      transition_to!(ACCEPTED, actor: actor, reason: "reclamado por #{lab_code}")
    end

    self
  end

  # The sample cannot be tested, and no test on it can run either. Rejecting the
  # order without rejecting its tests would leave a queue of work against a tube
  # that has already been thrown away.
  def reject!(reason:, actor: nil, note: nil)
    reference = reason.is_a?(Dictionary::Reference) ? reason : Dictionary::Reference.resolve("rejection_reasons", reason)

    self.class.transaction do
      self.rejection_reason_reference = reference
      transition_to!(REJECTED, actor: actor, reason: [ reference.label, note.presence ].compact.join(" — "))

      order_tests.each do |order_test|
        next if order_test.terminal?

        order_test.transition_to!(OrderTest::REJECTED, actor: actor, reason: reference.label)
      end
    end

    self
  end

  # For a change that lives outside this row — a test added at the laboratory.
  # The feed ships the order with its tests, so the order has to move for the
  # change to reach anyone.
  def touch_revision!
    self.class.transaction { update_column(:revision, Sequence.next_order_revision!) }
  end

  # Everything that happened under this tracking number, the order's own
  # transitions and its tests', in the order they happened. That is the question
  # an operator asks — "what happened to this sample" — and it is one index scan.
  def status_events
    StatusEvent.for_order(tracking_number)
  end

  def own_status_events
    StatusEvent.for_entity(uuid)
  end

  private

  # No uniqueness validation: a check-then-insert is precisely the race the
  # unique index exists to close, and it would only turn a collision that cannot
  # happen into a query on every order created.
  def assign_tracking_number
    return if tracking_number.present?

    # The unit that collected the sample, or the one working it. Either is a
    # stable prefix; what matters is that a sample is never left without a
    # number, because the number is what the clinic writes on the tube. The
    # laboratory is deliberately not a fallback — an order raised by an EMR has
    # none until a bench claims it, and a number cannot wait for that.
    prefix = sending_facility_code.presence || receiving_facility_code.presence

    # Nothing to build a number from yet. Leaving it unset lets the presence
    # validation say so, which is a far more useful answer than the generator's
    # exception.
    return if prefix.blank?

    self.tracking_number = TrackingNumber.generate(facility_code: prefix)
  end

  # Takes the sequence lock, which MySQL holds until this transaction commits,
  # so revision order and commit order are the same order.
  def assign_revision
    return unless new_record? || (changed - %w[revision updated_at]).any?

    self.revision = Sequence.next_order_revision!
  end
end
