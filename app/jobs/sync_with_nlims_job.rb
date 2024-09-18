# frozen_string_literal: true

# SyncWithNlimsJob job that syncs to local nlims
class SyncWithNlimsJob
  include Sidekiq::Job

  def perform(params)
    identifier, type, action = params.values_at('identifier', 'type', 'action')
    success = case type
              when 'test'
                tracking_number = Speciman.find_by(id: Test.find(identifier)&.specimen_id)&.tracking_number
                nlims = NlimsSyncUtilsService.new(tracking_number)
                nlims.push_test_actions_to_nlims(test_id: identifier, action:)
              when 'order'
                nlims = NlimsSyncUtilsService.new(identifier)
                if action == 'status_update'
                  order = Speciman.find_by(tracking_number: identifier)
                  nlims.push_order_update_to_nlims(order&.id)
                elsif action == 'order_create'
                  nlims.push_order_to_master_nlims(identifier)
                end
              when 'acknowlegment'
                nlims = NlimsSyncUtilsService.new(nil)
                acknowledgement = ResultsAcknwoledge.find_by(id: identifier)
                nlims.push_acknwoledgement_to_master_nlims(pending_acks: acknowledgement)
              else
                false
              end
    raise StandardError, "SyncWithNlimsJob failed for params: #{params}" unless success

    true
  end
end
