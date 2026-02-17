# frozen_string_literal: true

# Sync status and result to nlims
module  SyncToNlimsService
  class << self
    def push_status_to_nlims
      Rails.logger.info('[SyncToNlimsService] Starting push_status_to_nlims')
      StatusSyncTracker.where(
        sync_status: false,
        app: 'nlims'
      ).limit(1000).each do |tracker|
        Rails.logger.info("[SyncToNlimsService] Processing status for test_id: #{tracker&.test_id}")
        nlims = NlimsSyncUtilsService.new(tracking_number(tracker&.test_id))
        puts "Pushing status to nlims for test id: #{tracker&.test_id}"
        nlims.push_test_actions_to_nlims(test_id: tracker&.test_id, action: 'status_update')
      rescue StandardError => e
        Rails.logger.error("Failed to push test actions to NLMIS: #{e.message}")
      end
    end

    def push_order_to_nlims
      Rails.logger.info('[SyncToNlimsService] Starting push_order_to_nlims')
      OrderSyncTracker.where(
        synced: false
      ).limit(1000).each do |tracker|
        Rails.logger.info("[SyncToNlimsService] Processing order with tracking_number: #{tracker&.tracking_number}")
        nlims = NlimsSyncUtilsService.new(tracker&.tracking_number)
        nlims.push_order_to_master_nlims(tracker&.tracking_number)
      rescue StandardError => e
        Rails.logger.error("Failed to push order to NLMIS: #{e.message}")
      end
    end

    def force_sync_order_to_nlims
      Rails.logger.info('[SyncToNlimsService] Starting force_sync_order_to_nlims')
      specimen = Speciman.where.not(
        tracking_number: OrderSyncTracker.pluck(:tracking_number)
      )
      specimen.each do |order|
        Rails.logger.info("[SyncToNlimsService] Force syncing order with tracking_number: #{order&.tracking_number}")
        OrderSyncTracker.find_or_create_by(tracking_number: order&.tracking_number)
        nlims = NlimsSyncUtilsService.new(order&.tracking_number)
        nlims.push_order_to_master_nlims(order&.tracking_number)
      rescue StandardError => e
        Rails.logger.error("Failed to push order to NLMIS: #{e.message}")
      end
    end

    def push_result_to_nlims
      Rails.logger.info('[SyncToNlimsService] Starting push_result_to_nlims')
      ResultSyncTracker.where(
        sync_status: false,
        app: 'nlims'
      ).limit(1000).each do |tracker|
        Rails.logger.info("[SyncToNlimsService] Processing result for test_id: #{tracker&.test_id}")
        nlims = NlimsSyncUtilsService.new(tracking_number(tracker&.test_id))
        nlims.push_test_actions_to_nlims(test_id: tracker&.test_id, action: 'result_update')
      rescue StandardError => e
        Rails.logger.error("Failed to push test actions to NLMIS: #{e.message}")
      end
    end

    def push_added_tests_to_nlims
      Rails.logger.info('[SyncToNlimsService] Starting push_added_tests_to_nlims')
      AddedTestSyncTracker.where(
        sync_status: false,
        app: 'nlims'
      ).limit(1000).each do |tracker|
        Rails.logger.info("[SyncToNlimsService] Processing added test for test_id: #{tracker&.test_id}")
        nlims = NlimsSyncUtilsService.new(tracking_number(tracker&.test_id))
        puts "Pushing added test to nlims for test id: #{tracker&.test_id}"
        nlims.push_test_actions_to_nlims(test_id: tracker&.test_id, action: 'add_test')
      rescue StandardError => e
        Rails.logger.error("Failed to push added test to NLMIS: #{e.message}")
      end
    end

    def push_order_update_to_nlims
      Rails.logger.info('[SyncToNlimsService] Starting push_order_update_to_nlims')
      OrderStatusSyncTracker.where(
        sync_status: false
      ).limit(1000).each do |tracker|
        Rails.logger.info("[SyncToNlimsService] Processing order update for tracking_number: #{tracker&.tracking_number}")
        order = Speciman.find_by(tracking_number: tracker&.tracking_number)
        begin
          nlims = NlimsSyncUtilsService.new(order&.tracking_number)
          nlims.push_order_update_to_nlims(order&.id, status: tracker&.status)
        rescue StandardError => e
          Rails.logger.error("Failed to push order update to NLMIS: #{e.message}")
        end
      end
    end

    def push_acknwoledgement_to_master_nlims
      Rails.logger.info('[SyncToNlimsService] Starting push_acknwoledgement_to_master_nlims')
      nlims = NlimsSyncUtilsService.new(nil)
      nlims.push_acknwoledgement_to_master_nlims
    rescue StandardError => e
      Rails.logger.error("Failed to push acknowledgement to Master NLIMS: #{e.message}")
    end

    def synchronize_test_catalog
      Rails.logger.info('[SyncToNlimsService] Starting synchronize_test_catalog')
      ProcessTestCatalogService.synchronize_test_catalog
    end

    private

    def tracking_number(id)
      specimen_id = Test.find_by(id:)&.specimen_id
      Speciman.find_by(id: specimen_id)&.tracking_number
    end
  end
end
