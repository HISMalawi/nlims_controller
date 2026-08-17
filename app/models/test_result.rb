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

  belongs_to :order_test
  belongs_to :indicator

  validates :value, presence: true
  validates :recorded_at, presence: true
  validate :recorded_readings_are_never_rewritten

  scope :current, -> { where(replaced_by_uuid: nil) }
  scope :replaced, -> { where.not(replaced_by_uuid: nil) }
  scope :recorded_since, ->(time) { where(recorded_at: (time..)).order(:recorded_at, :id) }

  # The only way a result should be written. Takes the row lock on whatever this
  # indicator currently reads before inserting, so two corrections arriving
  # together cannot both leave themselves as the current one.
  def self.record!(order_test:, indicator:, value:, unit: nil, recorded_at: nil, recorded_by: nil)
    transaction do
      superseded = current.where(order_test: order_test, indicator: indicator).lock.to_a

      result = create!(
        order_test: order_test,
        indicator: indicator,
        value: value,
        unit: unit,
        recorded_at: recorded_at || Time.current,
        recorded_by: recorded_by
      )

      superseded.each { |row| row.update!(replaced_by_uuid: result.uuid) }

      result
    end
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

  def recorded_readings_are_never_rewritten
    return unless persisted?

    rewritten = changed & IMMUTABLE
    return if rewritten.empty?

    errors.add(:base, "a recorded result cannot be edited (#{rewritten.to_sentence}); record a new one instead")
  end
end
