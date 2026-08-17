# frozen_string_literal: true

# Collects samples referred to this node, and results produced elsewhere on
# samples it sent away. Local nodes only: the national node routes, it does not
# receive referrals of its own.
class SyncPullJob < ApplicationJob
  queue_as :sync

  def perform
    return unless SislabSync.local?

    if ENV["SISLAB_SYNC_NATIONAL_URL"].blank?
      Rails.logger.info("[sync pull] no national node configured, skipping")
      return
    end

    pull = Sync::Pull.from_env.call
    Rails.logger.info("[sync pull] #{pull.summary}")
  rescue NodeTransport::TransportError => e
    # An ordinary condition, not a bug to retry into a queue: it is recorded on
    # the cursor, where the dashboard can show it.
    Rails.logger.warn("[sync pull] #{e.message}")
  end
end
