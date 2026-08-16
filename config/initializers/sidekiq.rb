# frozen_string_literal: true

redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end

# The recurring jobs differ by mode: a local node pulls the dictionary and
# pushes its outbox, the national node has neither. Schedules are registered
# from S5 onwards; this is where they get gated.
Sidekiq.configure_server do |_config|
  next unless SislabSync.local?

  # S5 — DictionaryPullJob, every 5 minutes
  # S9 — SyncPushJob and the node heartbeat
  # S10 — SyncPullJob for inbound referrals
end
