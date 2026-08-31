# frozen_string_literal: true

# The person the sample came from.
#
# The national identifier is what makes one person one patient across the
# country, but a great many patients arrive without one, so it is unique where
# present and absent otherwise — never invented.
class Patient < ApplicationRecord
  include HasUuid

  SEXES = %w[F M Unknown].freeze

  has_many :orders, dependent: :restrict_with_error

  validates :name, presence: true
  validates :sex, inclusion: { in: SEXES }
  validates :national_id, uniqueness: { allow_blank: true }
  validate :birthdate_is_not_in_the_future

  normalizes :national_id, with: ->(value) { value.strip.upcase.presence }

  # Only when something a reader would notice has moved. A patient is touched by
  # every order raised for them, and an event per touch would fill the queue
  # with rows saying nothing changed.
  after_save :publish_to_outbox, if: :demographics_changed?

  scope :identified, -> { where.not(national_id: nil) }

  def identified?
    national_id.present?
  end

  # One person, however many facilities send them.
  #
  # The national identifier is the only thing that can say two arrivals are the
  # same person, so a patient who has one is looked up by it and updated with
  # whatever the sender knows; a patient without one is a new record every time,
  # because guessing from a name and a birthdate merges two people sooner or
  # later, and an unmerged duplicate is a far cheaper mistake than a merged pair.
  def self.upsert_from!(attributes)
    attributes = attributes.symbolize_keys.compact
    national_id = normalize_value_for(:national_id, attributes[:national_id])

    return create!(attributes) if national_id.blank?

    existing = find_by(national_id: national_id)
    return existing.tap { |patient| patient.update!(attributes) } if existing

    create!(attributes)
  rescue ActiveRecord::RecordNotUnique
    # Two of the EMR's retries arrived at once and both found no patient. The
    # one that lost the race takes the row the winner wrote.
    find_by!(national_id: national_id).tap { |patient| patient.update!(attributes) }
  end

  private

  DEMOGRAPHICS = %w[national_id name sex birthdate phone].freeze

  def demographics_changed?
    previously_new_record? || saved_changes.keys.intersect?(DEMOGRAPHICS)
  end

  # A patient created here is also carried inside order.created, so the national
  # node can apply an order for someone it has never heard of. This event is
  # what carries a later correction — a name spelled properly, an identifier
  # filled in afterwards.
  def publish_to_outbox
    OutboxEvent.record!(
      type: OutboxEvent::PATIENT_UPSERTED,
      aggregate_uuid: uuid,
      payload: PatientSerializer.call(self)
    )
  end

  def birthdate_is_not_in_the_future
    return if birthdate.blank? || birthdate <= Date.current

    errors.add(:birthdate, "cannot be in the future")
  end
end
