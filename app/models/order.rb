# frozen_string_literal: true

# One sample submitted for testing. Replaces the old `specimen` table.
class Order < ApplicationRecord
  include HasUuid
  include TracksStatus

  REQUESTED = "requested"
  ACCEPTED = "accepted"
  SPECIMEN_COLLECTED = "specimen_collected"
  IN_PROGRESS = "in_progress"
  REFERRED_OUT = "referred_out"
  COMPLETED = "completed"
  REJECTED = "rejected"
  CANCELLED = "cancelled"

  # referred_out leads to completed because the result comes back under this
  # same tracking number, whichever laboratory produced it. Receiving a referral
  # — referred_in — arrives with the rest of the referral machinery in S9.
  self.status_machine = StatusMachine.new(
    initial: REQUESTED,
    transitions: {
      REQUESTED => [ ACCEPTED, CANCELLED ],
      ACCEPTED => [ SPECIMEN_COLLECTED, REJECTED ],
      SPECIMEN_COLLECTED => [ IN_PROGRESS ],
      IN_PROGRESS => [ COMPLETED, REFERRED_OUT ],
      REFERRED_OUT => [ COMPLETED ]
    }
  )

  PRIORITIES = %w[routine urgent stat].freeze

  class AlreadyClaimed < StandardError; end

  belongs_to :patient
  belongs_to :specimen_type, optional: true
  belongs_to :source_client, class_name: "ApiClient", optional: true

  has_many :order_tests, dependent: :destroy
  has_many :test_results, through: :order_tests

  validates :tracking_number, presence: true
  validates :sending_facility_code, presence: true
  validates :receiving_lab_code, presence: true
  validates :priority, inclusion: { in: PRIORITIES }

  # Runs inside the transaction Active Record opens around the save, which is
  # what the sequence needs: the counter's lock has to be held until the row
  # that uses the number is committed.
  before_validation :assign_tracking_number, on: :create
  before_save :assign_revision

  scope :for_lab, ->(lab_code) { where(receiving_lab_code: lab_code) }
  scope :open, -> { where.not(status: [ COMPLETED, REJECTED, CANCELLED ]) }
  scope :unclaimed, -> { where(claimed_at: nil) }

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
  def claim!(lab_code:, actor: nil)
    self.class.transaction do
      taken = self.class.unclaimed.where(id: id)
                  .update_all(claimed_at: Time.current, claimed_by_lab_code: lab_code)

      raise AlreadyClaimed, "#{tracking_number} já foi reclamado por #{reload.claimed_by_lab_code}" if taken.zero?

      reload
      transition_to!(ACCEPTED, actor: actor, reason: "reclamado por #{lab_code}")
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

    # Nothing to build a number from yet. Leaving it unset lets the presence
    # validations say which codes are missing, which is a far more useful answer
    # than the generator's exception.
    return if sending_facility_code.blank?

    self.tracking_number = TrackingNumber.generate(facility_code: sending_facility_code)
  end

  # Takes the sequence lock, which MySQL holds until this transaction commits,
  # so revision order and commit order are the same order.
  def assign_revision
    return unless new_record? || (changed - %w[revision updated_at]).any?

    self.revision = Sequence.next_order_revision!
  end
end
