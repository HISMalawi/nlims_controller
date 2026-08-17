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

  Sidekiq::Cron::Job.load_from_hash!(
    "dictionary_pull" => {
      "cron" => ENV.fetch("DICTIONARY_PULL_CRON", "*/5 * * * *"),
      "class" => "DictionaryPullJob",
      "queue" => "sync"
    },
    # More often than the dictionary pull: a result waiting in the outbox is a
    # clinician waiting, while a dictionary five minutes out of date is nothing.
    # The job carries the heartbeat too, so a node with an empty outbox still
    # reports in and cannot be mistaken for one that has fallen over.
    "sync_push" => {
      "cron" => ENV.fetch("SYNC_PUSH_CRON", "* * * * *"),
      "class" => "SyncPushJob",
      "queue" => "sync"
    }
  )

  # S10 — SyncPullJob for inbound referrals
end
