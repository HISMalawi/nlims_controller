# frozen_string_literal: true

require 'emr_sync_service'

#  TestStatusTrail Model
class TestStatusTrail < ApplicationRecord
  after_commit :push_status_to_emr, on: %i[create update], if: :local_nlims?
  after_commit :push_status_to_local_nlims, on: %i[create update], unless: :local_nlims?
  after_commit :push_status_to_master_nlims, on: %i[create update], if: :local_nlims?

  private

  def local_nlims?
    Config.local_nlims?
  end

  def push_status_to_emr
    return if !Config.master_update_source?(tracking_number) && Config.same_source?(tracking_number)

    status = TestStatus.find_by(id: test_status_id)&.name
    time_updated ||= updated_at
    StatusSyncTracker.create(tracking_number:, test_id:, status:, time_updated:, app: 'emr')
    SyncWithEmrJob.perform_async(tracking_number, status, test_id, time_updated)
  end

  def push_status_to_master_nlims
    return if Config.master_update_source?(tracking_number)

    status = TestStatus.find_by(id: test_status_id)&.name
    time_updated ||= updated_at
    StatusSyncTracker.create(tracking_number:, test_id:, status:,
                             time_updated:, app: 'nlims')
    SyncWithNlimsJob.perform_async(test_id, type: 'test', action: 'status_update')
  end

  def push_status_to_local_nlims
    return if Config.same_source?(tracking_number)

    status = TestStatus.find_by(id: test_status_id)&.name
    time_updated ||= updated_at
    StatusSyncTracker.create(tracking_number:, test_id:, status:,
                             time_updated:, app: 'nlims')
    SyncWithNlimsJob.perform_async(test_id, type: 'test', action: 'status_update')
  end

  def tracking_number
    Speciman.find(Test.find(test_id).specimen_id)&.tracking_number
  end
end
