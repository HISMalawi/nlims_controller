# frozen_string_literal: true

# The spine every dictionary record shares: a uuid that crosses node boundaries,
# a readable national code, a publication status, and the revision the
# replication cursor walks.
module DictionaryEntry
  extend ActiveSupport::Concern

  COUNTRY = "MOZ"

  DRAFT = "draft"
  ACTIVE = "active"
  RETIRED = "retired"

  STATUSES = [ DRAFT, ACTIVE, RETIRED ].freeze

  # A draft has never been published, so withholding it costs a local node
  # nothing. active and retired have both been seen and must keep flowing.
  PUBLISHED_STATUSES = [ ACTIVE, RETIRED ].freeze

  class Withdrawn < StandardError; end

  included do
    include HasUuid

    class_attribute :national_code_prefix, instance_writer: false

    # Who is publishing this, and why. Travels with the record so the callback
    # that writes the history does not have to read ambient state.
    attr_accessor :status_actor, :status_reason

    # Set when this entry is a copy of one that arrived from another node. The
    # revision then comes from the feed instead of being allocated here: there
    # is one national revision space, and a local node inventing its own numbers
    # would hand the SISLAB revisions the national node never issued.
    attr_accessor :replicated_revision

    validates :name, presence: true
    validates :status, inclusion: { in: STATUSES }
    validate :publication_is_not_withdrawn
    validate :loinc_code_is_well_formed

    before_save :assign_national_code
    before_save :assign_revision
    before_save :stamp_retirement
    after_save :record_status_change, if: :status_worth_recording?

    scope :published, -> { where(status: PUBLISHED_STATUSES) }
    scope :drafts, -> { where(status: DRAFT) }
    scope :active, -> { where(status: ACTIVE) }
    scope :retired, -> { where(status: RETIRED) }

    # What a local node asks for. Drafts are invisible here by construction, not
    # by the caller remembering to filter them out.
    scope :changed_since, lambda { |cursor|
      published.where(revision: ((cursor.to_i + 1)..)).order(:revision, :id)
    }
  end

  class_methods do
    def entity_type
      table_name
    end

    # What the feed needs loaded alongside each entry. Overridden by the types
    # that ship links or ranges inline, so serialising a batch of 500 is a
    # handful of queries rather than a few thousand.
    def delta_includes
      []
    end
  end

  def draft?    = status == DRAFT
  def active?   = status == ACTIVE
  def retired?  = status == RETIRED
  def published? = PUBLISHED_STATUSES.include?(status)

  def activate!(actor: nil, reason: nil)
    change_status!(ACTIVE, actor: actor, reason: reason)
  end

  # Nothing is deleted once it has been published: a local node holding the old
  # copy has to be told it is gone, and a delete leaves nothing to tell it with.
  def retire!(actor: nil, reason: nil)
    change_status!(RETIRED, actor: actor, reason: reason)
  end

  # For a change that lives outside this row — a specimen type linked to a test
  # type, a range added to an indicator. The delta ships those inline, so the
  # owning record has to move for the change to reach anyone.
  def touch_revision!
    self.class.transaction do
      update_column(:revision, Sequence.next_revision!)
    end
  end

  private

  def assign_national_code
    return if national_code.present?
    raise "#{self.class} has no national_code_prefix" if national_code_prefix.blank?

    number = Sequence.next!("national_code:#{national_code_prefix}")
    self.national_code = format("#{COUNTRY}-%s-%04d", national_code_prefix, number)
  end

  # Takes the sequence lock, which MySQL holds until this transaction commits.
  # That is what makes revision order and commit order the same order.
  def assign_revision
    if replicated_revision.present?
      self.revision = replicated_revision
      return
    end

    return unless revision_worthy_change?

    self.revision = Sequence.next_revision!
  end

  def revision_worthy_change?
    return true if new_record?

    (changed - %w[revision updated_at]).any?
  end

  def stamp_retirement
    self.deleted_at = retired? ? (deleted_at || Time.current) : nil
  end

  def change_status!(status, actor:, reason:)
    self.status_actor = actor
    self.status_reason = reason
    update!(status: status)
  end

  # Creation counts. A new entry's status usually equals the column default, so
  # Active Record sees no change to report — the history would then start at the
  # first promotion and show nothing about where the entry came from.
  def status_worth_recording?
    previously_new_record? || saved_change_to_status?
  end

  # There are no published versions to point at, so this history is the only
  # record of how the dictionary reached its current state.
  def record_status_change
    DictionaryStatusChange.record!(
      self,
      from: saved_change_to_status&.first,
      actor: status_actor,
      reason: status_reason
    )
  end

  # A wrong LOINC code is worse than none: it states confidently that a test is
  # something it is not, and it says so to every system that reads it. The check
  # digit is what catches the single mistyped character, which is the way these
  # are actually got wrong — they are copied out of a browser tab by hand.
  #
  # Blank stays allowed. Most of the catalogue has no code yet, and refusing to
  # save an entry until somebody has curated it would stop the laboratory
  # working over a field that is only useful outside the country.
  def loinc_code_is_well_formed
    return if loinc_code.blank?
    return if Dictionary::Loinc.check_digit_valid?(loinc_code)

    errors.add(:loinc_code, "#{loinc_code} não é um código LOINC válido")
  end

  # Un-publishing would strand every node that already has the record: they
  # would keep serving a copy nobody can withdraw. Retire it instead.
  def publication_is_not_withdrawn
    return unless persisted? && status_changed?
    return unless PUBLISHED_STATUSES.include?(status_was) && status == DRAFT

    errors.add(:status, "cannot go back to draft once published; retire it instead")
  end
end
