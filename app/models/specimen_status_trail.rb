# frozen_string_literal: true

# Model class for specimen status trail
class SpecimenStatusTrail < ApplicationRecord
  after_commit :push_order_update_to_local_nlims

  def push_order_update_to_local_nlims
    OrderStatusSyncTracker.create(tracking_number: tracking_number, status: status)
    test_id = Test.find_by(specimen_id: specimen_id)&.id
    local_nlims_sync_service = LocalNlimsSyncService.new(test_id)
    local_nlims_sync_service.push_order_update_to_local_nlims(specimen_id)
  end
end
