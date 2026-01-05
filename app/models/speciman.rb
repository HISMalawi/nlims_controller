# frozen_string_literal: true

# Specimen model
class Speciman < ApplicationRecord
  belongs_to :specimen_types, class_name: 'SpecimenType', foreign_key: 'specimen_type_id'
  belongs_to :specimen_statuses, class_name: 'SpecimenStatus', foreign_key: 'specimen_status_id'
  belongs_to :wards, class_name: 'Ward', foreign_key: 'ward_id'
  has_many :tests, dependent: :restrict_with_error, foreign_key: 'specimen_id'
  has_many :specimen_status_trail, class_name: 'SpecimenStatusTrail', foreign_key: 'specimen_id'

  after_commit :push_order_to_master_nlims, on: %i[create], if: :local_nlims?
  after_update :push_order_update_to_master_nlims, if: -> { local_nlims? && saved_change_to_specimen_type_id? }

  private

  def local_nlims?
    Config.local_nlims?
  end

  def push_order_to_master_nlims
    return if specimen_type_id == SpecimenType.get_specimen_type_id('not_specified')

    OrderSyncTracker.find_or_create_by(tracking_number:)
    SyncWithNlimsJob.perform_async({
      identifier: tracking_number,
      type: 'order',
      action: 'order_create'
    }.stringify_keys)
  end

  def push_order_update_to_master_nlims
    return if specimen_type_id == SpecimenType.get_specimen_type_id('not_specified')

    OrderSyncTracker.find_or_create_by(tracking_number:)
    SyncWithNlimsJob.perform_async({
      identifier: tracking_number,
      type: 'order',
      action: 'order_create'
    }.stringify_keys)
  end
end
