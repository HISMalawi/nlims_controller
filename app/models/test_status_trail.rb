# frozen_string_literal: true

require 'emr_sync_service'
require 'local_nlims_sync_service'

#  TestStatusTrail Model
class TestStatusTrail < ApplicationRecord
  after_commit :push_status_to_emr, on: %i[create update], if: :local_nlims?
  after_commit :push_status_to_local_nlims, on: %i[create update], unless: :local_nlims?

  private

  def local_nlims?
    Config.local_nlims?
  end

  def push_status_to_emr
    status = TestStatus.find_by(id: test_status_id)&.name
    time_updated = time_updated
    time_updated ||= updated_at
    unless Config.master_update_source?(tracking_number)
      # push statutes to master nlims
      StatusSyncTracker.create(tracking_number: tracking_number, test_id: test_id, status: status, time_updated: time_updated, app: 'nlims')
      local_nlims = LocalNlimsSyncService.new(nil)
      local_nlims.push_test_actions_to_nlims(test_id: test_id, action: 'status_update')
    end
    #  emr_service = emr_service.emr_instance_for_sync(emr_service, tracking_number)
    unless Config.same_source?(tracking_number)
      StatusSyncTracker.create(tracking_number: tracking_number, test_id: test_id, status: status, time_updated: time_updated, app: 'emr')
      emr_service = EmrSyncService.new
      res = emr_service.push_status_to_emr(tracking_number, status, time_updated)
      StatusSyncTracker.find_by(tracking_number: tracking_number, test_id: test_id, status: status, app: 'emr')&.update(sync_status: res)
    end
  end

  def push_status_to_local_nlims
    unless Config.same_source?(tracking_number)
      StatusSyncTracker.create(tracking_number: tracking_number, test_id: test_id, status: status, time_updated: time_updated, app: 'nlims')
      local_nlims = LocalNlimsSyncService.new(tracking_number)
      local_nlims.push_test_actions_to_nlims(test_id: test_id, action: 'status_update')
    end
  end

  def tracking_number
    Speciman.find(Test.find(test_id).specimen_id)&.tracking_number
  end
end
