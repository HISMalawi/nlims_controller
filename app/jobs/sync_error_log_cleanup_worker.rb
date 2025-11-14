# frozen_string_literal: true

# SyncErrorLogCleanupWorker
class SyncErrorLogCleanupWorker
  include Sidekiq::Worker
  sidekiq_options lock: :until_executed,
                  on_conflict: :reject

  def perform
    SyncErrorLog.delete_by(['created_at < ?', 6.hours.ago])
  end
end
