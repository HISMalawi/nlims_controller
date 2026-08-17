# frozen_string_literal: true

# The outbox, as something an operator can act on rather than a table only a
# console can see.
#
# Nothing here deletes a row. A delivered event is the evidence it was sent, and
# a failed one stays in the queue where somebody can read the national node's
# complaint and do something about it.
class SyncQueueController < ApplicationController
  PER_PAGE = 100

  FILTERS = %w[failing pending delivered].freeze

  def index
    @filter = params[:filter].presence_in(FILTERS) || "pending"

    @events = scope.offset((page - 1) * PER_PAGE).limit(PER_PAGE).to_a
    @total = scope.count
    @page = page
    @pages = [ (@total / PER_PAGE.to_f).ceil, 1 ].max

    @pending = OutboxEvent.pending.count
    @failing = OutboxEvent.failing.count
    @heartbeat = SyncCursor.for(SyncCursor::HEARTBEAT)
  end

  # Puts one event back at the front of the queue. Not a resend: the push job
  # does the sending, and this only clears the backoff that is making it wait.
  def retry
    event = OutboxEvent.find(params[:id])
    event.retry_now!

    enqueue_push

    redirect_back fallback_location: sync_queue_path, notice: t(".queued", uuid: event.event_uuid)
  end

  # After the national node has been fixed, or the network has come back, an
  # operator should not have to click through two hundred rows that are all
  # waiting on the same thing.
  def retry_all
    count = OutboxEvent.failing.count
    OutboxEvent.failing.find_each(&:retry_now!)

    enqueue_push

    redirect_to sync_queue_path, notice: t(".queued_all", count: count)
  end

  private

  def scope
    relation = OutboxEvent.order(id: :desc)

    case @filter
    when "failing" then relation.failing
    when "delivered" then relation.delivered
    else relation.pending
    end
  end

  # The retry is only meaningful if something goes and tries. Asking now rather
  # than waiting for the next scheduled run is the difference between a button
  # that works and a button that appears to do nothing.
  def enqueue_push
    SyncPushJob.perform_later
  rescue StandardError => e
    # Redis being down is not a reason to refuse the retry: the row has already
    # been cleared and the next scheduled run will pick it up.
    Rails.logger.warn("[sync queue] could not enqueue a push: #{e.class}: #{e.message}")
  end

  def page
    [ params[:page].to_i, 1 ].max
  end
end
