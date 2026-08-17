# frozen_string_literal: true

# One event waiting for one node to come and collect it.
class InboundDelivery < ApplicationRecord
  belongs_to :inbound_event

  scope :for_node, ->(node_code) { where(node_code: node_code) }
  scope :changed_since, lambda { |cursor|
    where(revision: ((cursor.to_i + 1)..)).order(:revision, :id)
  }

  def self.cursor
    Sequence.current(Sequence::DELIVERY_REVISION)
  end

  # Idempotent: routing runs as each event is applied, and an event applied once
  # is never applied again, but a node that appears twice in the interested list
  # should still be told once.
  def self.queue!(node_code, event)
    create!(node_code: node_code, inbound_event: event,
            revision: Sequence.next!(Sequence::DELIVERY_REVISION), created_at: Time.current)
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
