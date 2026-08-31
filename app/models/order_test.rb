# frozen_string_literal: true

# One test requested on one sample.
#
# Tests move through their own states rather than the order's: a panel of three
# can have one completed, one running and one rejected for want of sample, and
# the order is not any of those things.
class OrderTest < ApplicationRecord
  include HasUuid
  include TracksStatus
  include DictionaryTerms

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

  # The exam, as the request named it. The dictionary entry is filled in when
  # this node knows the term and left empty when it does not — a laboratory can
  # run an exam the national catalogue has not reached yet.
  dictionary_term :test_type, entity: "test_types", name: :test_name, code: :test_code
  dictionary_term :test_panel, entity: "test_panels", name: :panel_name, code: :panel_code

  validate :test_is_named

  has_many :test_results, dependent: :destroy

  delegate :tracking_number, to: :order

  scope :open, -> { where.not(status: [ COMPLETED, REJECTED, CANCELLED ]) }

  def status_events
    StatusEvent.for_entity(uuid)
  end

  # What this test is called, whatever it is linked to.
  def label
    test_type_label
  end

  # What this test currently says, one reading per indicator. Corrections are
  # excluded by pointing forward: a row that has been replaced names the row
  # that replaced it.
  def current_results
    test_results.current
  end

  private

  # The one thing that is still required. A test with no exam on it is not a
  # loose end anybody can tie up later — nobody would know what was asked for.
  def test_is_named
    return if test_type_reference.present?

    errors.add(:base, "um teste tem de indicar o exame, por código ou por nome")
  end
end
