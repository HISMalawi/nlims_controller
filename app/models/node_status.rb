# frozen_string_literal: true

# The numbers the dashboard is made of, gathered in one place.
#
# An operator opens this screen to answer one question — is this node talking to
# the capital, and if not, how far behind is it — so the counts that answer it
# are computed together and can be asserted on directly, rather than being
# assembled out of a dozen scopes inside a view.
#
# Both modes are served from the same object because half the answers are the
# same in both, and the ones that are not are missing rather than wrong: a local
# node has an outbox and no nodes table, the national node the reverse.
class NodeStatus
  # The dashboard is read at a glance and should not cost a table scan. Order
  # counts are the only ones that could grow without bound, so they are taken
  # over a window rather than over everything.
  RECENT = 24.hours

  def self.call(now: Time.current)
    new(now: now)
  end

  def initialize(now: Time.current)
    @now = now
  end

  # --- Both modes ---------------------------------------------------------

  def open_orders
    @open_orders ||= Order.open.count
  end

  def orders_recently_created
    @orders_recently_created ||= Order.where(created_at: @now - RECENT..).count
  end

  def orders_by_status
    @orders_by_status ||= Order.group(:status).count
  end

  def referrals_in_transit
    @referrals_in_transit ||= Referral.outstanding.count
  end

  def referrals_awaiting_arrival
    @referrals_awaiting_arrival ||= Referral.outstanding.for_node(SislabSync.node_code).count
  end

  def dictionary_counts
    @dictionary_counts ||= Dictionary.models.index_by(&:entity_type).transform_values { |model| model.active.count }
  end

  def dictionary_entries
    dictionary_counts.values.sum
  end

  # --- Local node ---------------------------------------------------------

  def outbox_pending
    @outbox_pending ||= OutboxEvent.pending.count
  end

  def outbox_failing
    @outbox_failing ||= OutboxEvent.failing.count
  end

  # How old the oldest thing still waiting is — the number that says whether the
  # link has been down for ten minutes or since Friday.
  def outbox_lag
    return nil if oldest_pending_at.nil?

    @now - oldest_pending_at
  end

  def oldest_pending_at
    return @oldest_pending_at if defined?(@oldest_pending_at)

    @oldest_pending_at = OutboxEvent.pending.minimum(:occurred_at)
  end

  def last_delivered_at
    @last_delivered_at ||= OutboxEvent.delivered.maximum(:delivered_at)
  end

  # The most recent thing the national node refused or the link failed on.
  # Shown as it was written, because the operator who has to act on it is the
  # one who will read the national node's own message.
  def last_push_error
    @last_push_error ||= OutboxEvent.failing.order(updated_at: :desc).pick(:last_error)
  end

  def heartbeat
    @heartbeat ||= SyncCursor.for(SyncCursor::HEARTBEAT)
  end

  def dictionary_cursor
    @dictionary_cursor ||= SyncCursor.for(SyncCursor::DICTIONARY)
  end

  def inbound_cursor
    @inbound_cursor ||= SyncCursor.for(SyncCursor::INBOUND)
  end

  # A node that has never reached the capital and one that reached it a minute
  # ago are the two ends of the only question this screen exists to answer.
  def reachable?
    heartbeat.last_synced_at.present? && heartbeat.healthy?
  end

  # Not the same as "has never succeeded". A node freshly installed and one that
  # has been failing since it was installed both have no successful sync, and
  # only the second has something for an operator to act on — so having tried
  # and failed counts as having started.
  def never_synced?
    heartbeat.last_synced_at.nil? && heartbeat.last_attempted_at.nil?
  end

  # --- National node ------------------------------------------------------

  def nodes
    @nodes ||= Node.count
  end

  def stale_nodes
    @stale_nodes ||= Node.stale(@now).count
  end

  def nodes_behind
    @nodes_behind ||= Node.behind.count
  end

  def inbound_pending
    @inbound_pending ||= InboundEvent.pending.count
  end

  def inbound_rejected
    @inbound_rejected ||= InboundEvent.rejected.count
  end

  # Pending is normal — an event whose predecessor has not landed waits, and the
  # gap usually fills seconds later. Pending for an hour is not.
  def inbound_stalled
    @inbound_stalled ||= InboundEvent.stalled(older_than: @now - 1.hour).count
  end

  def events_received_recently
    @events_received_recently ||= InboundEvent.where(received_at: @now - RECENT..).count
  end

  def dictionary_drafts
    @dictionary_drafts ||= Dictionary.models.sum { |model| model.drafts.count }
  end
end
