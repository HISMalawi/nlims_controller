# frozen_string_literal: true

# SyncErrorLog for logging errors in syncing orders to EMR
class SyncErrorLog < ApplicationRecord
  after_create :clean_up_after_24_hours

  def clean_up_after_24_hours
    SyncErrorLog.where('created_at < ?', 24.hours.ago).delete_all
  end
end
