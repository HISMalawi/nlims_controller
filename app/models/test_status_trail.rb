# frozen_string_literal: true

require 'emr_sync_service'

#  TestStatusTrail Model
class TestStatusTrail < ApplicationRecord
  after_commit :push_status_to_emr, if: :local_nlims?

  private

  def local_nlims?
    Config.local_nlims?
  end

  def push_status_to_emr
    status = TestStatus.find_by(id: test_status_id)&.name
    time_updated = time_updated
    time_updated ||= updated_at
    StatusSyncTracker.create(tracking_number: tracking_number, test_id: test_id, status: status, time_updated: time_updated)
    response = if local_nlims?
                 emr_service = EmrSyncService.new
                 emr_service = emr_service.emr_instance_for_sync(emr_service, tracking_number)
                 emr_service.push_status_to_emr(tracking_number, status, time_updated)
               else
                 local_nlims = LocalNlimsSyncService.new(test_id)
                 local_nlims.push_test_actions_to_local_nlims(test_id: test_id, action: 'status_update')
               end
    return unless response

    StatusSyncTracker.find_by(tracking_number: tracking_number, test_id: test_id, status: status)&.update(sync_status: true)
  end

  def tracking_number
    Speciman.find(Test.find(test_id).specimen_id).tracking_number
  end
end
