# frozen_string_literal: true

# One test requested on one sample.
#
# Tests move through their own states rather than the order's: a panel of three
# can have one completed, one running and one rejected for want of sample, and
# the order is not any of those things.
class OrderTest < ApplicationRecord
  include HasUuid
  include TracksStatus

  PENDING = "pending"
  IN_PROGRESS = "in_progress"
  COMPLETED = "completed"
  REJECTED = "rejected"
  CANCELLED = "cancelled"

  # completed is terminal. A corrected reading is a new result row on a test
  # that stays completed — reopening the test would make the correction look
  # like a second run of the same test.
  self.status_machine = StatusMachine.new(
    initial: PENDING,
    transitions: {
      PENDING => [ IN_PROGRESS, REJECTED, CANCELLED ],
      IN_PROGRESS => [ COMPLETED, REJECTED ]
    }
  )

  belongs_to :order
  belongs_to :test_type
  belongs_to :test_panel, optional: true

  has_many :test_results, dependent: :destroy

  delegate :tracking_number, to: :order

  scope :open, -> { where.not(status: [ COMPLETED, REJECTED, CANCELLED ]) }

  def status_events
    StatusEvent.for_entity(uuid)
  end

  # What this test currently says, one reading per indicator. Corrections are
  # excluded by pointing forward: a row that has been replaced names the row
  # that replaced it.
  def current_results
    test_results.current
  end
end
