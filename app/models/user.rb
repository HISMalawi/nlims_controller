# frozen_string_literal: true

# A person who signs in to the operator interface.
#
# Deliberately not an ApiClient. A client is a system that holds a key and calls
# the API on behalf of a whole facility; a user is a person who holds a password
# and acts as themselves. Mixing them would mean either a person's password
# could call the API or a key could open the interface, and neither should be
# possible.
class User < ApplicationRecord
  include HasUuid

  # Two roles, because there are only two decisions to make: everyone who can
  # open the interface can look at everything and put a failed event back in the
  # queue; issuing keys and changing the dictionary is the administrator's.
  OPERATOR = "operator"
  ADMIN = "admin"

  ROLES = [ OPERATOR, ADMIN ].freeze

  MINIMUM_PASSWORD_LENGTH = 12

  has_secure_password

  has_many :sessions, dependent: :destroy

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: ROLES }
  validates :password, length: { minimum: MINIMUM_PASSWORD_LENGTH }, allow_nil: true

  scope :enabled, -> { where(active: true) }

  # nil for every failure — unknown address, wrong password, disabled account —
  # so the sign-in screen cannot be used to find out which addresses exist.
  def self.authenticate(email:, password:)
    user = enabled.find_by(email: email.to_s.strip.downcase)

    if user.nil?
      # Hash anyway. Returning early would make an unknown address answer
      # measurably faster than a wrong password, and the timing would tell a
      # prober exactly what the message is refusing to.
      BCrypt::Password.create(password.to_s)
      return nil
    end

    user.authenticate(password) || nil
  end

  def admin?
    role == ADMIN
  end

  # What goes in the `actor` column of a status event or on an issued key: a
  # person, named, rather than "the interface".
  def to_actor
    "#{name} <#{email}>"
  end
end
