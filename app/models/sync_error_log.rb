# frozen_string_literal: true

# SyncErrorLog for logging errors in syncing orders to EMR
class SyncErrorLog < ApplicationRecord
  after_commit :schedule_cleanup, on: :create

  def error_details=(value)
    super(value.is_a?(Hash) || value.is_a?(Array) ? value.to_json : value)
  end

  private

  def schedule_cleanup
    SyncErrorLogCleanupWorker.perform_async
  end
end
