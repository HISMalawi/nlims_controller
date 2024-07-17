# frozen_string_literal: true

require 'emr_sync_service'

#  TestStatusTrail Model
class TestStatusTrail < ApplicationRecord
  after_create :push_status_to_emr

  def push_status_to_emr
    emr_service = EmrSyncService.new
    status = TestStatus.find_by(id: test_status_id)&.name
    StatusSyncTracker.create(tracking_number: tracking_number, status: status, time_updated: time_updated)
    response = emr_service.push_status_to_emr(tracking_number, status, time_updated)
    return unless response

    StatusSyncTracker.find_by(tracking_number: tracking_number, status: status)&.update(sync_status: true)
  end

  def tracking_number
    Speciman.find(Test.find(test_id).specimen_id).tracking_number
  end
end
