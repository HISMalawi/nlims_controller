# frozen_string_literal: true

require 'master_nlims_sync_service'

# Test model
class Test < ApplicationRecord
  after_commit :push_order_to_master_nlims, on: %i[create], if: :local_nlims?

  private

  def local_nlims?
    Config.local_nlims?
  end

  def push_order_to_master_nlims
    master = MasterNlimsSyncService.new
    payload = master.build_order_payload(tracking_number)
    OrderSyncTracker.find_or_create_by(tracking_number:)
    response = master.push_order_to_master_nlims(payload)
    OrderSyncTracker.find_by(tracking_number:).update(synced: true) if response
  end

  def tracking_number
    Speciman.find_by(id: Test.find(id)&.specimen_id)&.tracking_number
  end
end
