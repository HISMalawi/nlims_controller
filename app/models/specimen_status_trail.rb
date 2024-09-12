# frozen_string_literal: true

require 'local_nlims_sync_service'

# Model class for specimen status trail
class SpecimenStatusTrail < ApplicationRecord
  after_commit :push_status_to_master_nlims, on: %i[create update], unless: :local_nlims?
  after_commit :push_status_to_local_nlims, on: %i[create update], if: :local_nlims?

  private

  def local_nlims?
    Config.local_nlims?
  end

  def push_status_to_master
    OrderStatusSyncTracker.create(tracking_number: tracking_number, status: status)
    local_nlims_sync_service = LocalNlimsSyncService.new(nil)
    local_nlims_sync_service.push_order_update_to_nlims(specimen_id)
  end

  def push_status_to_local_nlims
    OrderStatusSyncTracker.create(tracking_number: tracking_number, status: status)
    local_nlims_sync_service = LocalNlimsSyncService.new(tracking_number)
    local_nlims_sync_service.push_order_update_to_nlims(specimen_id)
  end

  def tracking_number
    Speciman.find_by(id: specimen_id)&.tracking_number
  end
end
