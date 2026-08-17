# frozen_string_literal: true

# How far this node has read someone else's feed. Advanced only after a batch
# has been applied and committed, so a crash mid-batch costs a re-read and never
# a skipped change.
class SyncCursor < ApplicationRecord
  DICTIONARY = "dictionary"
  INBOUND = "inbound"

  # Not a cursor over anybody's feed — it has no value to advance. It is here
  # because "when did this node last reach the capital, and what did it say if
  # it failed" is the same three columns, and the dashboard reads them the same
  # way as the other two.
  HEARTBEAT = "heartbeat"

  validates :name, presence: true, uniqueness: true

  def self.for(name)
    find_by(name: name) || create!(name: name)
  rescue ActiveRecord::RecordNotUnique
    find_by!(name: name)
  end

  def self.value_for(name)
    where(name: name).pick(:value) || 0
  end

  def advance!(value)
    return mark_synced! if value.to_i <= self.value

    update!(value: value, last_synced_at: Time.current, last_error: nil, consecutive_failures: 0)
  end

  # A run that found nothing new still succeeded, and an operator needs to see
  # that the node is talking to the national one rather than stuck.
  def mark_synced!
    update!(last_synced_at: Time.current, last_error: nil, consecutive_failures: 0)
  end

  def touch_attempt!
    update!(last_attempted_at: Time.current)
  end

  def record_failure!(error)
    update!(
      last_attempted_at: Time.current,
      last_error: error.to_s.truncate(1000),
      consecutive_failures: consecutive_failures + 1
    )
  end

  def healthy?
    consecutive_failures.zero?
  end
end
