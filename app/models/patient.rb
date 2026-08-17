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

  scope :identified, -> { where.not(national_id: nil) }

  def identified?
    national_id.present?
  end

  private

  def birthdate_is_not_in_the_future
    return if birthdate.blank? || birthdate <= Date.current

    errors.add(:birthdate, "cannot be in the future")
  end
end
