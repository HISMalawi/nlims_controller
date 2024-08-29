# frozen_string_literal: true

require 'local_nlims_sync_service'
require 'sync_util_service'

namespace :nlims do
  desc 'TODO'
  task sync_to_local: :environment do
    push_order_update_to_local_nlims
    push_status_to_local_nlims
    push_result_to_local_nlims
  end
end

def push_status_to_local_nlims
  StatusSyncTracker.where(
    sync_status: false,
    created_at: (Date.today - 120)..Date.today + 1
  ).each do |tracker|
    local_nlims = LocalNlimsSyncService.new(tracker&.test_id)
    local_nlims.push_test_actions_to_local_nlims(test_id: tracker&.test_id, action: 'status_update')
  end
end

def push_result_to_local_nlims
  ResultSyncTracker.where(
    sync_status: false,
    created_at: (Date.today - 120)..Date.today + 1
  ).each do |tracker|
    local_nlims = LocalNlimsSyncService.new(tracker&.test_id)
    local_nlims.push_test_actions_to_local_nlims(test_id: tracker&.test_id, action: 'result_update')
  end
end

def push_order_update_to_local_nlims
  OrderStatusSyncTracker.where(
    sync_status: false,
    created_at: (Date.today - 120)..Date.today + 1
  ).each do |tracker|
    order = Speciman.find_by(tracking_number: tracker&.tracking_number)
    test_id = Test.find_by(specimen_id: order&.id)&.id
    local_nlims = LocalNlimsSyncService.new(test_id)
    local_nlims.push_order_update_to_local_nlims(order_id)
  end
end
