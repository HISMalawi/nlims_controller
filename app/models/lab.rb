# frozen_string_literal: true

# A laboratory on the network.
#
# A laboratory is not a node. It sits inside a health facility, several to a
# unit, and reaches the country through that unit's node. What identifies it
# here is the pair (facility, source_code): `source_code` is the code the LIS
# knows it by, unique inside one mLab instance and meaningless outside it.
#
# There are two ways an entry comes to exist. The capital creates it and
# publishes it down the dictionary feed, or a local node meets it for the first
# time on an arriving sample and registers it — with no national code, because
# only the capital issues those. The second kind is announced upwards, named in
# the capital, and comes back down the feed as the first kind.
class Lab < ApplicationRecord
  include DictionaryEntry

  self.national_code_prefix = "LAB"

  belongs_to :facility, primary_key: :national_code, foreign_key: :facility_code,
                        inverse_of: :labs, optional: true

  validates :source_code, uniqueness: { scope: :facility_code }, allow_nil: true

  # A laboratory registered here has to reach the capital, which is the only
  # place a national code comes from. Announced on creation and not on every
  # save: the capital owns the entry from then on, and a node correcting a
  # spelling locally is not an instruction to the country.
  after_create :announce_registration, if: :announceable?

  scope :ordered, -> { order(:name) }
  scope :awaiting_national_code, -> { where(national_code: nil) }
  scope :in_facility, ->(facility_code) { where(facility_code: facility_code) }

  # A laboratory this node registered and the capital has not named yet. It
  # works — samples are taken, results are reported — it simply cannot be
  # referred to from another unit until it has a code the country agrees on.
  def local?
    national_code.blank?
  end

  # What this laboratory is addressed by outside its own unit.
  def code
    national_code.presence || source_code
  end

  # Every code this laboratory has ever been written down as.
  #
  # A laboratory registered here is recorded on samples under its LIS code, and
  # under the national one from the day the capital names it. Both stand: what a
  # sample was written with is what it keeps. So a feed asked for one of them has
  # to answer with the work filed under either, or the day the capital catches up
  # is the day a bench's older samples disappear from its queue.
  def codes
    [ national_code, source_code ].compact_blank.uniq
  end

  def label
    [ code, name ].compact_blank.join(" — ")
  end

  def place
    facility&.place
  end

  # The capital issues national codes; a local node registers laboratories
  # without one and waits to be told.
  def assign_national_code?
    SislabSync.national?
  end

  # Register a laboratory this node has just met, or return the one it already
  # knows. Called from inside the transaction that is creating the sample, so a
  # unit whose LIS is seen for the first time is not a request that fails.
  #
  # The entry stays a draft: it is this node's own note of a laboratory, not
  # something the country has agreed to, and the feed only carries what has been
  # published. It becomes published here when the capital's copy arrives.
  def self.register_local!(source_code:, facility_code:, name:, phone: nil, description: nil)
    code = source_code.to_s.strip
    return nil if code.blank?

    existing = find_by(facility_code: facility_code, source_code: code)
    return existing if existing

    create!(
      facility_code: facility_code,
      source_code: code,
      name: name.presence || code,
      phone: phone,
      description: description,
      status: DictionaryEntry::DRAFT
    )
  end

  # The register's answer to a code arriving from outside: a national code
  # first, since that is what another unit would use, and this unit's own LIS
  # code second.
  def self.find_by_any_code(code, facility_code: nil)
    return nil if code.blank?

    find_by(national_code: code) || find_by(facility_code: facility_code, source_code: code)
  end

  private

  # Only a laboratory this node registered itself, on a local node, and only
  # when it was written here rather than replicated in from the feed — the
  # applier stamps `replicated_revision` on everything it applies, and sending
  # the capital's own entry back to it would have the country registering its
  # laboratories once per node that heard of them.
  def announceable?
    SislabSync.local? && local? && replicated_revision.blank?
  end

  def announce_registration
    OutboxEvent.record!(
      type: OutboxEvent::LAB_REGISTERED,
      aggregate_uuid: uuid,
      payload: {
        "uuid" => uuid,
        "source_code" => source_code,
        "facility_code" => facility_code,
        "name" => name,
        "short_name" => short_name,
        "description" => description,
        "phone" => phone
      }
    )
  end
end
