# frozen_string_literal: true

# Keeps this node's dictionary in step with the national one. Scheduled every
# five minutes on local nodes only; the national node owns the dictionary and
# has nobody to pull from.
class DictionaryPullJob < ApplicationJob
  queue_as :sync

  def perform
    return unless SislabSync.local?

    if ENV["SISLAB_SYNC_NATIONAL_URL"].blank?
      Rails.logger.info("[dictionary pull] no national node configured, skipping")
      return
    end

    puller = Dictionary::Puller.from_env.call
    Rails.logger.info("[dictionary pull] #{puller.summary}")
  rescue Dictionary::Puller::TransportError => e
    # The link to the capital being down is an ordinary condition here, not a
    # bug to retry into a queue. It is recorded on the cursor, where the
    # dashboard can show it.
    Rails.logger.warn("[dictionary pull] #{e.message}")
  end
end
