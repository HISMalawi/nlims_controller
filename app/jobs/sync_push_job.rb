# frozen_string_literal: true

# Empties the outbox towards the national node, and says the node is alive
# whether or not there was anything to send. Scheduled on local nodes only; the
# national node receives and has nobody to push to.
class SyncPushJob < ApplicationJob
  queue_as :sync

  def perform
    return unless SislabSync.local?

    if ENV["SISLAB_SYNC_NATIONAL_URL"].blank?
      Rails.logger.info("[sync push] no national node configured, skipping")
      return
    end

    transport = NodeTransport.from_env

    push = Sync::Push.new(transport: transport).call
    Rails.logger.info("[sync push] #{push.summary}")

    heartbeat(transport)
  rescue NodeTransport::TransportError => e
    # The link to the capital being down is an ordinary condition here, not a
    # bug to retry into a queue: the events keep their place in the outbox with
    # their backoff, and the next run picks them up.
    Rails.logger.warn("[sync push] #{e.message}")
  end

  private

  # Reported after the push, so the numbers it carries are the ones the national
  # node would see if it looked now.
  def heartbeat(transport)
    Sync::Heartbeat.new(transport: transport).call
  rescue NodeTransport::TransportError => e
    Rails.logger.warn("[sync heartbeat] #{e.message}")
  end
end
