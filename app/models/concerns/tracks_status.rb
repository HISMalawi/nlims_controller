# frozen_string_literal: true

# A record whose status moves by an explicit machine and leaves a trail.
#
# The rule is enforced as a validation rather than only inside `transition_to!`,
# so a status changed by any other route — a bare `update`, an import, the
# console — is refused in exactly the same way, and refused before anything is
# written. Callers get `ActiveRecord::RecordInvalid`, which the API layer
# already renders as a 422.
module TracksStatus
  extend ActiveSupport::Concern

  included do
    class_attribute :status_machine, instance_writer: false

    # Who moved this and why. Travels with the record so the callback that
    # writes the history does not have to read ambient state — the same reason
    # DictionaryEntry carries its actor rather than reading a thread local.
    attr_accessor :status_actor, :status_reason

    validate :status_is_known
    validate :status_transition_exists

    after_save :record_status_event, if: :status_worth_recording?

    scope :with_status, ->(*statuses) { where(status: statuses.flatten) }
  end

  class_methods do
    def entity_type
      table_name
    end
  end

  def transition_to!(status, actor: nil, reason: nil)
    self.status_actor = actor
    self.status_reason = reason
    update!(status: status)
  end

  def may_transition_to?(status)
    status_machine.allows?(self.status, status)
  end

  def next_statuses
    status_machine.next_statuses(status)
  end

  def terminal?
    status_machine.terminal?(status)
  end

  private

  def status_is_known
    return if status_machine.include?(status)

    errors.add(:status, "#{status.inspect} is not a status this record can hold")
  end

  # Creation is not a transition: an order replicated from another node arrives
  # mid-lifecycle, and refusing it because it did not start at the first status
  # would make a referral impossible to receive.
  def status_transition_exists
    return unless persisted? && status_changed?
    return if status_machine.allows?(status_was, status)

    errors.add(:status, "cannot go from #{status_was} to #{status}")
  end

  # Creation counts. Without it the history would begin at the first transition
  # and say nothing about the state the record was born in.
  def status_worth_recording?
    previously_new_record? || saved_change_to_status?
  end

  def record_status_event
    StatusEvent.record!(
      self,
      from: saved_change_to_status&.first,
      actor: status_actor,
      reason: status_reason
    )
  end
end
