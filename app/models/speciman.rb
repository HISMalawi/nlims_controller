# frozen_string_literal: true

# Specimen model
class Speciman < ApplicationRecord
  belongs_to :specimen_types, class_name: 'SpecimenType', foreign_key: 'specimen_type_id'

  after_commit :push_order_to_master_nlims, on: %i[create], if: :local_nlims?
  after_commit :push_order_update_to_master_nlims, on: %i[update], if: :local_nlims?

  private

  def local_nlims?
    Config.local_nlims?
  end

  def push_order_to_master_nlims
    return if specimen_type_id.zero?

    OrderSyncTracker.find_or_create_by(tracking_number:)
    SyncWithNlimsJob.perform_async({
      identifier: tracking_number,
      type: 'order',
      action: 'order_create'
    }.stringify_keys)
  end

  def push_order_update_to_master_nlims
    return unless saved_change_to_specimen_type_id
    return if specimen_type_id.zero?

    OrderSyncTracker.find_or_create_by(tracking_number:)
    SyncWithNlimsJob.perform_async({
      identifier: tracking_number,
      type: 'order',
      action: 'order_create'
    }.stringify_keys)
  end
end
