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

  scope :for_lab, ->(lab_code) { where(receiving_lab_code: lab_code) }
  scope :open, -> { where.not(status: [ COMPLETED, REJECTED, CANCELLED ]) }

  def self.find_by_tracking_number!(tracking_number)
    find_by!(tracking_number: tracking_number)
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
end
