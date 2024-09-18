# frozen_string_literal: true

# Model class for specimen status trail
class SpecimenStatusTrail < ApplicationRecord
  after_commit :push_status_to_master_nlims, on: %i[create update], if: :local_nlims?
  after_commit :push_status_to_local_nlims, on: %i[create update], unless: :local_nlims?

  private

  def local_nlims?
    Config.local_nlims?
  end

  def push_status_to_master_nlims
    return if Config.master_update_source?(tracking_number)

    OrderStatusSyncTracker.create(tracking_number:, status:)
    SyncWithNlimsJob.perform_async({
      identifier: tracking_number,
      type: 'order',
      action: 'status_update'
    }.stringify_keys)
  end

  def push_status_to_local_nlims
    return if Config.same_source?(tracking_number)

    OrderStatusSyncTracker.create(tracking_number:, status:)
    SyncWithNlimsJob.perform_async({
      identifier: tracking_number,
      type: 'order',
      action: 'status_update'
    }.stringify_keys)
  end

  def tracking_number
    Speciman.find_by(id: specimen_id)&.tracking_number
  end

  def status
    SpecimenStatus.find_by(id: specimen_status_id)&.name
  end
end
