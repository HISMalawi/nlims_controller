# frozen_string_literal: true

# SyncErrorLogCleanupWorker
class SyncErrorLogCleanupWorker
  include Sidekiq::Worker

  def perform
    SyncErrorLog.delete_by(['created_at < ?', 6.hours.ago])
  end
end
