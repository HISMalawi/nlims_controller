# frozen_string_literal: true

# SyncToLocalNlimsJob job that syncs to local nlims
class SyncToLocalNlimsJob
  include Sidekiq::Job

  def perform
    SyncToLocalNlims.push_order_update_to_local_nlims
    SyncToLocalNlims.push_status_to_local_nlims
    SyncToLocalNlims.push_result_to_local_nlims
  end
end
