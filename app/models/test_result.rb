# frozen_string_literal: true

# One reading against one indicator.
#
# Nothing here is ever rewritten. Correcting a value writes a new row and marks
# the old one as replaced by it, because the national node may already have
# distributed the wrong value — an overwrite would leave the two nodes disagreeing
# with no record of which reading came second.
class TestResult < ApplicationRecord
  include HasUuid
  include DictionaryTerms

  # Everything that describes the reading itself. `replaced_by_uuid` is
  # deliberately absent: marking a row as superseded is the one change a
  # recorded result is allowed to undergo.
  IMMUTABLE = %w[uuid order_test_id indicator_id indicator_name indicator_code value unit recorded_at
                 recorded_by].freeze

  # What a polling client is owed a new revision for. Acknowledgement is
  # deliberately absent: an EMR that confirms a reading would otherwise move the
  # cursor and be handed its own confirmation back, for ever.
  PUBLISHABLE = (IMMUTABLE + %w[replaced_by_uuid]).freeze

  belongs_to :order_test
  has_one :order, through: :order_test

  # What was measured. Linked to the dictionary when the indicator is in it, and
  # kept by name when it is not: a reading nobody can file is still a reading,
  # and the exam it belongs to may not be in the catalogue either.
  dictionary_term :indicator, entity: "indicators", name: :indicator_name, code: :indicator_code

  validate :indicator_is_named

  validates :value, presence: true
  validates :recorded_at, presence: true
  validate :recorded_readings_are_never_rewritten

  before_save :assign_revision
  after_create :publish_to_outbox

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
    reference = indicator.is_a?(Dictionary::Reference) ? indicator : Dictionary::Reference.resolve("indicators", indicator)

    transaction do
      # The replacement's uuid is settled first so the old row can be marked
      # before the new one is written. A client reading by revision then learns
      # that what it holds is superseded before it is handed the reading that
      # superseded it, rather than the other way round.
      uuid = SecureRandom.uuid

      supersede(order_test, reference).lock.each { |row| row.update!(replaced_by_uuid: uuid) }

      result = new(
        uuid: uuid,
        order_test: order_test,
        value: value,
        unit: unit,
        recorded_at: recorded_at || Time.current,
        recorded_by: recorded_by
      )
      result.indicator_reference = reference
      result.save!
      result
    end
  end

  # The readings this one replaces: the same indicator on the same test. An
  # indicator in the dictionary is matched by its row, one that is not by the
  # name it was recorded under — which is the only handle a free term has, and
  # is why two spellings of the same thing stand as two readings rather than
  # one silently overwriting the other.
  def self.supersede(order_test, reference)
    rows = current.where(order_test: order_test)

    if reference.known?
      rows.where(indicator_id: reference.entry.id)
    else
      rows.where(indicator_id: nil, indicator_name: reference.name)
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

  # Written in the transaction that wrote the reading. A correction names the
  # readings it supersedes: they were marked before this row was created, so the
  # list is already there to be read.
  def publish_to_outbox
    OutboxEvent.record!(
      type: OutboxEvent::TEST_RESULT_RECORDED,
      aggregate_uuid: order_test.order.uuid,
      payload: TestResultSerializer.call(self, context: true).merge(
        replaces: self.class.where(replaced_by_uuid: uuid).pluck(:uuid)
      ),
      occurred_at: recorded_at
    )
  end

  # Takes the sequence lock, which MySQL holds until this transaction commits.
  # That is what makes revision order and commit order the same order, and it is
  # the whole reason a client may move its cursor and never look back.
  def assign_revision
    return unless new_record? || (changed & PUBLISHABLE).any?

    self.revision = Sequence.next_result_revision!
  end

  # A reading has to say what it measured, by code or by name. Without either
  # there is a number on a screen and nothing to say what it is a number of.
  def indicator_is_named
    return if indicator_reference.present?

    errors.add(:base, "um resultado tem de indicar o indicador, por código ou por nome")
  end

  def recorded_readings_are_never_rewritten
    return unless persisted?

    rewritten = changed & IMMUTABLE
    return if rewritten.empty?

    errors.add(:base, "a recorded result cannot be edited (#{rewritten.to_sentence}); record a new one instead")
  end
end
