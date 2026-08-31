# frozen_string_literal: true

# A node the national one has heard from.
class Node < ApplicationRecord
  # Long enough that a node pushing every few minutes is not called stale for a
  # single missed run, short enough that a laboratory offline since yesterday is
  # obvious this morning.
  STALE_AFTER = 30.minutes

  validates :node_code, presence: true, uniqueness: true

  scope :stale, ->(now = Time.current) { where(last_seen_at: ...(now - STALE_AFTER)) }
  scope :behind, -> { where("outbox_pending > 0") }

  def self.heard_from!(node_code, attributes = {})
    node = find_or_initialize_by(node_code: node_code)
    node.assign_attributes(attributes.compact.merge(last_seen_at: Time.current))
    node.save!
    node
  end

  def stale?(now = Time.current)
    last_seen_at.nil? || last_seen_at < (now - STALE_AFTER)
  end
end
