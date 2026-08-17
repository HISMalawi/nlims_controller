# frozen_string_literal: true

# One reading against one indicator.
#
# Nothing here is ever rewritten. Correcting a value writes a new row and marks
# the old one as replaced by it, because the national node may already have
# distributed the wrong value — an overwrite would leave the two nodes disagreeing
# with no record of which reading came second.
class TestResult < ApplicationRecord
  include HasUuid

  # Everything that describes the reading itself. `replaced_by_uuid` is
  # deliberately absent: marking a row as superseded is the one change a
  # recorded result is allowed to undergo.
  IMMUTABLE = %w[uuid order_test_id indicator_id value unit recorded_at recorded_by].freeze

  # What a polling client is owed a new revision for. Acknowledgement is
  # deliberately absent: an EMR that confirms a reading would otherwise move the
  # cursor and be handed its own confirmation back, for ever.
  PUBLISHABLE = (IMMUTABLE + %w[replaced_by_uuid]).freeze

  belongs_to :order_test
  belongs_to :indicator
  has_one :order, through: :order_test

  validates :value, presence: true
  validates :recorded_at, presence: true
  validate :recorded_readings_are_never_rewritten

  before_save :assign_revision

  scope :current, -> { where(replaced_by_uuid: nil) }
  scope :replaced, -> { where.not(replaced_by_uuid: nil) }
  scope :acknowledged, -> { where.not(acknowledged_at: nil) }
  scope :unacknowledged, -> { where(acknowledged_at: nil) }
  scope :recorded_since, ->(time) { where(recorded_at: (time..)).order(:recorded_at, :id) }

  # What a client that polls with a cursor asks for. Corrections travel too: an
  # EMR that already filed the wrong value has to be told it was superseded, and
  # marking the old row moves it as surely as writing the new one does.
  scope :changed_since, lambda { |cursor|
    where(revision: ((cursor.to_i + 1)..)).order(:revision, :id)
  }

  scope :for_facility, lambda { |facility_code|
    next all if facility_code.blank?

    joins(order_test: :order).where(orders: { sending_facility_code: facility_code })
  }

  scope :for_patient_national_id, lambda { |national_id|
    next all if national_id.blank?

    joins(order_test: { order: :patient })
      .where(patients: { national_id: Patient.normalize_value_for(:national_id, national_id) })
  }

  # The only way a result should be written. Takes the row lock on whatever this
  # indicator currently reads before inserting, so two corrections arriving
  # together cannot both leave themselves as the current one.
  def self.record!(order_test:, indicator:, value:, unit: nil, recorded_at: nil, recorded_by: nil)
    transaction do
      # The replacement's uuid is settled first so the old row can be marked
      # before the new one is written. A client reading by revision then learns
      # that what it holds is superseded before it is handed the reading that
      # superseded it, rather than the other way round.
      uuid = SecureRandom.uuid

      current.where(order_test: order_test, indicator: indicator).lock.each do |row|
        row.update!(replaced_by_uuid: uuid)
      end

      create!(
        uuid: uuid,
        order_test: order_test,
        indicator: indicator,
        value: value,
        unit: unit,
        recorded_at: recorded_at || Time.current,
        recorded_by: recorded_by
      )
    end
  end

  # Where a client that has seen everything would leave its cursor.
  def self.cursor
    Sequence.current(Sequence::RESULT_REVISION)
  end

  def acknowledge!(by:)
    update!(acknowledged_at: Time.current, acknowledged_by: by)
  end

  def acknowledged?
    acknowledged_at.present?
  end

  def replaced?
    replaced_by_uuid.present?
  end

  def current?
    !replaced?
  end

  def replaced_by
    return if current?

    self.class.find_by(uuid: replaced_by_uuid)
  end

  private

  # Takes the sequence lock, which MySQL holds until this transaction commits.
  # That is what makes revision order and commit order the same order, and it is
  # the whole reason a client may move its cursor and never look back.
  def assign_revision
    return unless new_record? || (changed & PUBLISHABLE).any?

    self.revision = Sequence.next_result_revision!
  end

  def recorded_readings_are_never_rewritten
    return unless persisted?

    rewritten = changed & IMMUTABLE
    return if rewritten.empty?

    errors.add(:base, "a recorded result cannot be edited (#{rewritten.to_sentence}); record a new one instead")
  end
end
