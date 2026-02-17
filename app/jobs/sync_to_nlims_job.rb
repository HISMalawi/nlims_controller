# frozen_string_literal: true

# Job to sync orders, tests, results, and status to NLIMS
class SyncToNlimsJob
  include Sidekiq::Job
  sidekiq_options lock: :until_executed,
                  on_conflict: :log,
                  queue: :critical

  def perform
    Rails.logger.info('[SyncToNlimsJob] Starting sync operations')

    sync_test_catalog
    sync_orders
    force_sync_orders
    sync_order_updates
    sync_added_tests
    sync_status_updates
    sync_results
    sync_acknowledgements

    Rails.logger.info('[SyncToNlimsJob] Completed all sync operations')
  rescue StandardError => e
    Rails.logger.error("[SyncToNlimsJob] Error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end

  private

  def sync_test_catalog
    return unless Config.local_nlims?

    Rails.logger.info('[SyncToNlimsJob] Synchronizing Test Catalog')
    SyncToNlimsService.synchronize_test_catalog
  rescue StandardError => e
    Rails.logger.error("Error in sync_test_catalog: #{e.message}")
  end

  def sync_orders
    return unless Config.local_nlims?

    Rails.logger.info('[SyncToNlimsJob] Pushing Orders to NLIMS')
    SyncToNlimsService.push_order_to_nlims
  rescue StandardError => e
    Rails.logger.error("Error in sync_orders: #{e.message}")
  end

  def force_sync_orders
    return unless Config.local_nlims?

    Rails.logger.info('[SyncToNlimsJob] Force Pushing Orders to NLIMS')
    SyncToNlimsService.force_sync_order_to_nlims
  rescue StandardError => e
    Rails.logger.error("Error in force_sync_orders: #{e.message}")
  end

  def sync_order_updates
    Rails.logger.info('[SyncToNlimsJob] Pushing Order Updates to NLIMS')
    SyncToNlimsService.push_order_update_to_nlims
  rescue StandardError => e
    Rails.logger.error("Error in sync_order_updates: #{e.message}")
  end

  def sync_added_tests
    return unless Config.local_nlims?

    Rails.logger.info('[SyncToNlimsJob] Pushing Added Tests to NLIMS')
    SyncToNlimsService.push_added_tests_to_nlims
  rescue StandardError => e
    Rails.logger.error("Error in sync_added_tests: #{e.message}")
  end

  def sync_status_updates
    Rails.logger.info('[SyncToNlimsJob] Pushing Status Updates to NLIMS')
    SyncToNlimsService.push_status_to_nlims
  rescue StandardError => e
    Rails.logger.error("Error in sync_status_updates: #{e.message}")
  end

  def sync_results
    Rails.logger.info('[SyncToNlimsJob] Pushing Results to NLIMS')
    SyncToNlimsService.push_result_to_nlims
  rescue StandardError => e
    Rails.logger.error("Error in sync_results: #{e.message}")
  end

  def sync_acknowledgements
    return unless Config.local_nlims?

    Rails.logger.info('[SyncToNlimsJob] Pushing Acknowledgements to NLIMS')
    SyncToNlimsService.push_acknwoledgement_to_master_nlims
  rescue StandardError => e
    Rails.logger.error("Error in sync_acknowledgements: #{e.message}")
  end
end
