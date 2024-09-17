# frozen_string_literal: true

# SyncWithNlimsJob job that syncs to local nlims
class SyncWithNlimsJob
  include Sidekiq::Job

  def perform(identifier, type: 'test', action: 'status_update')
    if type == 'test'
      tracking_number = Speciman.find_by(id: Test.find(identifier)&.specimen_id)&.tracking_number
      nlims = NlimsSyncUtilsService.new(tracking_number)
      nlims.push_test_actions_to_nlims(test_id: identifier, action:)
    elsif type == 'order' && action == 'status_update'
      order = Speciman.find_by(tracking_number: identifier)
      nlims = NlimsSyncUtilsService.new(identifier)
      nlims.push_order_update_to_nlims(order&.id)
    elsif type == 'order' && action == 'order_create'
      nlims = NlimsSyncUtilsService.new(identifier)
      nlims.push_order_to_master_nlims(identifier)
    elsif type == 'acknowlegment'
      nlims = NlimsSyncUtilsService.new(nil)
      nlims.push_acknwoledgement_to_master_nlims(pending_acks: identifier)
    end
  end
end
