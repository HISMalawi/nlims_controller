# frozen_string_literal: true

require 'local_nlims_sync_service'
require 'sync_util_service'

# Sync status and result to local nlims
module  SyncToLocalNlims
  class << self
    def push_status_to_local_nlims
      StatusSyncTracker.where(
        sync_status: false,
        created_at: (Date.today - 120)..Date.today + 1
      ).each do |tracker|
        local_nlims = LocalNlimsSyncService.new(tracking_number(tracker&.test_id))
        local_nlims.push_test_actions_to_local_nlims(test_id: tracker&.test_id, action: 'status_update')
      end
    end

    def push_result_to_local_nlims
      ResultSyncTracker.where(
        sync_status: false,
        created_at: (Date.today - 120)..Date.today + 1
      ).each do |tracker|
        local_nlims = LocalNlimsSyncService.new(tracking_number(tracker&.test_id))
        local_nlims.push_test_actions_to_local_nlims(test_id: tracker&.test_id, action: 'result_update')
      end
    end

    def push_order_update_to_local_nlims
      OrderStatusSyncTracker.where(
        sync_status: false,
        created_at: (Date.today - 120)..Date.today + 1
      ).each do |tracker|
        order = Speciman.find_by(tracking_number: tracker&.tracking_number)
        local_nlims = LocalNlimsSyncService.new(order&.tracking_number)
        local_nlims.push_order_update_to_local_nlims(order&.id)
      end
    end

    private

    def tracking_number(id)
      specimen_id = Test.find_by(id:)&.specimen_id
      Speciman.find_by(id: specimen_id)&.tracking_number
    end
  end
end
