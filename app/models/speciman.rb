# frozen_string_literal: true

# Specimen model
class Speciman < ApplicationRecord
  after_commit :push_order_to_master_nlims, on: %i[create update], if: :local_nlims?

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
end
