# frozen_string_literal: true

# Sync status and result to nlims
module  SyncToNlimsService
  class << self
    def push_status_to_nlims
      StatusSyncTracker.where(
        sync_status: false,
        app: 'nlims',
        created_at: (Date.today - 120)..Date.today + 1
      ).each do |tracker|
        nlims = NlimsSyncUtilsService.new(tracking_number(tracker&.test_id))
        nlims.push_test_actions_to_nlims(test_id: tracker&.test_id, action: 'status_update')
      end
    end

    def push_order_to_nlims
      OrderStatusSyncTracker.where(
        synced: false,
        created_at: (Date.today - 120)..Date.today + 1
      ).each do |tracker|
        nlims = NlimsSyncUtilsService.new(tracker&.tracking_number)
        nlims.push_order_to_master_nlims(tracker&.tracking_number)
      end
    end

    def push_result_to_nlims
      ResultSyncTracker.where(
        sync_status: false,
        app: 'nlims',
        created_at: (Date.today - 120)..Date.today + 1
      ).each do |tracker|
        nlims = NlimsSyncUtilsService.new(tracking_number(tracker&.test_id))
        nlims.push_test_actions_to_nlims(test_id: tracker&.test_id, action: 'result_update')
      end
    end

    def push_order_update_to_nlims
      OrderStatusSyncTracker.where(
        sync_status: false,
        created_at: (Date.today - 120)..Date.today + 1
      ).each do |tracker|
        order = Speciman.find_by(tracking_number: tracker&.tracking_number)
        nlims = NlimsSyncUtilsService.new(order&.tracking_number)
        nlims.push_order_update_to_nlims(order&.id)
      end
    end

    def push_acknwoledgement_to_master_nlims
      nlims = NlimsSyncUtilsService.new(nil)
      nlims.push_acknwoledgement_to_master_nlims
    end

    private

    def tracking_number(id)
      specimen_id = Test.find_by(id:)&.specimen_id
      Speciman.find_by(id: specimen_id)&.tracking_number
    end
  end
end
