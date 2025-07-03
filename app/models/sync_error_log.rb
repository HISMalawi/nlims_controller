# frozen_string_literal: true

# SyncErrorLog for logging errors in syncing orders to EMR
class SyncErrorLog < ApplicationRecord
  after_commit :schedule_cleanup, on: :create

  private

  def schedule_cleanup
    SyncErrorLogCleanupWorker.perform_async
  end
end
