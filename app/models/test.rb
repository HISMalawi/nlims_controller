# frozen_string_literal: true

# Test model
class Test < ApplicationRecord
  after_commit :push_order_to_master_nlims, on: %i[create], if: :local_nlims?

  private

  def local_nlims?
    Config.local_nlims?
  end

  def push_order_to_master_nlims
    return if order&.specimen_type_id&.zero?

    OrderSyncTracker.create(tracking_number: order&.tracking_number)
    SyncWithNlimsJob.perform_async(order&.tracking_number, type: 'order', action: 'order_create')
  end

  def order
    Speciman.find_by(id: Test.find(id)&.specimen_id)
  end
end
