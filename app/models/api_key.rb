# frozen_string_literal: true

# Token format: ssk_<env>_<prefix>_<secret>
#
#   ssk_prod_a1b2c3d4_9fK2mZq7XvR4tLpN8sJdW3yH6bC1
#       │    │        └─ secret, 32 chars, only ever exists on the client
#       │    └────────── public prefix, indexed, one lookup per request
#       └─────────────── environment, so a staging key cannot work in production
#
# Only the SHA-256 of the whole token is stored. A lost key cannot be recovered,
# only replaced.
class ApiKey < ApplicationRecord
  include HasUuid

  SCOPES = %w[
    orders:read
    orders:write
    results:read
    results:write
    referrals:write
    dictionary:read
    dictionary:write
    sync:push
    sync:pull
  ].freeze

  PREFIX_LENGTH = 8
  SECRET_LENGTH = 32

  # Writing last_used_at on every request would turn each read into a write.
  # Minute resolution is enough to answer "is this key still in use?".
  LAST_USED_RESOLUTION = 1.minute

  belongs_to :api_client

  # Not `serialize`: its Type::Serialized returns NULL whenever the value equals
  # the coder's default, so a key issued with no scopes would violate the NOT
  # NULL constraint instead of storing "[]".
  attribute :scopes, :json, default: []

  validates :prefix, presence: true, uniqueness: true
  validates :key_digest, presence: true
  validate :scopes_are_known

  scope :usable, -> { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }

  class << self
    # Returns [record, token]. The token is the only time the secret exists in
    # this process; the caller must show it to the operator and forget it.
    def issue!(api_client:, scopes:, expires_at: nil, issued_by: nil)
      prefix = generate_prefix
      secret = SecureRandom.alphanumeric(SECRET_LENGTH)
      token = "ssk_#{environment_segment}_#{prefix}_#{secret}"

      record = create!(
        api_client: api_client,
        prefix: prefix,
        key_digest: digest(token),
        scopes: Array(scopes).map(&:to_s),
        expires_at: expires_at,
        issued_by: issued_by
      )

      [ record, token ]
    end

    # nil for anything that is not a live key: unparseable, unknown prefix,
    # wrong secret, revoked, expired, or belonging to a disabled client. The
    # caller gets one undifferentiated 401, so a probe learns nothing about
    # which of those it hit.
    def authenticate(token)
      prefix = extract_prefix(token)
      return nil if prefix.blank?

      key = usable.includes(:api_client).find_by(prefix: prefix)
      return nil unless key
      return nil unless ActiveSupport::SecurityUtils.secure_compare(key.key_digest, digest(token))
      return nil unless key.api_client.active?

      key
    end

    def digest(token)
      Digest::SHA256.hexdigest(token)
    end

    def extract_prefix(token)
      return nil unless token.is_a?(String)

      parts = token.split("_")
      return nil unless parts.length == 4 && parts.first == "ssk"
      return nil unless parts.second == environment_segment

      parts.third.presence
    end

    def environment_segment
      case Rails.env
      when "production" then "prod"
      when "staging" then "staging"
      else "dev"
      end
    end

    private

    def generate_prefix
      loop do
        candidate = SecureRandom.alphanumeric(PREFIX_LENGTH).downcase
        return candidate unless exists?(prefix: candidate)
      end
    end
  end

  def allows?(scope)
    scopes.include?(scope.to_s)
  end

  def revoked?
    revoked_at.present?
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def usable?
    !revoked? && !expired? && api_client.active?
  end

  def revoke!(at: Time.current)
    update!(revoked_at: at)
  end

  def touch_last_used!(now: Time.current)
    return if last_used_at.present? && last_used_at > now - LAST_USED_RESOLUTION

    update_column(:last_used_at, now)
  end

  # What an operator sees in the interface and in the audit trail.
  def masked_token
    "ssk_#{self.class.environment_segment}_#{prefix}_#{'•' * 8}"
  end

  private

  def scopes_are_known
    unknown = Array(scopes).map(&:to_s) - SCOPES
    return if unknown.empty?

    errors.add(:scopes, "unknown: #{unknown.join(', ')}")
  end
end
