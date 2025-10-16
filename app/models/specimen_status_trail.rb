# frozen_string_literal: true

# Model class for specimen status trail
class SpecimenStatusTrail < ApplicationRecord
  belongs_to :specimen_status, class_name: 'SpecimenStatus', foreign_key: 'specimen_status_id'

  after_commit :push_status_to_master_nlims, on: %i[create], if: :local_nlims?
  after_commit :push_status_to_local_nlims, on: %i[create], unless: :local_nlims?

  private

  def local_nlims?
    Config.local_nlims?
  end

  def push_status_to_master_nlims
    return if Config.master_update_source?(tracking_number)
    return if OrderStatusSyncTracker.exists?(tracking_number:, status:)

    OrderStatusSyncTracker.create(tracking_number:, status:)
    SyncWithNlimsJob.perform_async({
      identifier: tracking_number,
      type: 'order',
      action: 'status_update'
    }.stringify_keys)
  end

  def push_status_to_local_nlims
    return if Config.same_source?(tracking_number)
    return if !local_nlims? && !Config.host_valid?(tracking_number)
    return if OrderStatusSyncTracker.exists?(tracking_number:, status:)

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
