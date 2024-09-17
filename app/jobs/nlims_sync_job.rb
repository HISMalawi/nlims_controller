# frozen_string_literal: true

# NlimsSyncJob job that syncs to local nlims
class NlimsSyncJob
  include Sidekiq::Job

  def perform
    SyncToNlimsService.push_order_to_nlims if Config.local_nlims?
    # SyncToNlimsService.push_order_update_to_nlims
    # SyncToNlimsService.push_status_to_nlims
    # SyncToNlimsService.push_result_to_nlims
    # SyncToNlimsService.push_acknwoledgement_to_master_nlims if Config.local_nlims?
  end
end
NlimsSyncJob.perform_async
