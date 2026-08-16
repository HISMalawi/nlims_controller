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

    validates :name, presence: true
    validates :status, inclusion: { in: STATUSES }
    validate :publication_is_not_withdrawn

    before_save :assign_national_code
    before_save :assign_revision
    before_save :stamp_retirement

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
  end

  def draft?    = status == DRAFT
  def active?   = status == ACTIVE
  def retired?  = status == RETIRED
  def published? = PUBLISHED_STATUSES.include?(status)

  def activate!
    update!(status: ACTIVE)
  end

  # Nothing is deleted once it has been published: a local node holding the old
  # copy has to be told it is gone, and a delete leaves nothing to tell it with.
  def retire!
    update!(status: RETIRED)
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

  # Un-publishing would strand every node that already has the record: they
  # would keep serving a copy nobody can withdraw. Retire it instead.
  def publication_is_not_withdrawn
    return unless persisted? && status_changed?
    return unless PUBLISHED_STATUSES.include?(status_was) && status == DRAFT

    errors.add(:status, "cannot go back to draft once published; retire it instead")
  end
end
