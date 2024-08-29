# frozen_string_literal: true

require 'master_nlims_sync_service'
require 'emr_sync_service'
require 'sync_util_service'

namespace :master_nlims do
  desc 'TODO'
  task sync_data: :environment do
    mns = MasterNlimsSyncService.new
    mns.process_orders

    re_push_status_to_emr
    re_push_result_to_emr
    push_acknwoledgement_to_master_nlims
  end
end

def re_push_status_to_emr
  StatusSyncTracker.where(
    sync_status: false,
    created_at: (Date.today - 120)..Date.today + 1
  ).each do |tracker|
    emr_service = EmrSyncService.new
    response = emr_service.push_status_to_emr(
      tracker.tracking_number, tracker.status,
      tracker.time_updated
    )
    next unless response

    StatusSyncTracker.find_by(
      tracking_number: tracker.tracking_number,
      test_id: tracker.test_id,
      status: tracker.status
    )&.update(sync_status: true)
  end
end

def re_push_acknwoledgement_to_master_nlims
  pending_acks = ResultsAcknwoledge.where(
    acknwoledged_to_nlims: false,
    created_at: (Date.today - 120)..Date.today + 1
  )
  pending_acks = nil if pending_acks.empty?
  master_nlims_service = MasterNlimsSyncService.new
  master_nlims_service.push_acknwoledgement_to_master_nlims(
    pending_acks: pending_acks
  )
end

def re_push_result_to_emr
  ResultSyncTracker.where(
    sync_status: false,
    created_at: (Date.today - 120)..Date.today + 1
  ).each do |tracker|
    emr_service = EmrSyncService.new
    response = emr_service.push_result_to_emr(tracker.tracking_number)
    next unless response

    emr_service.push_status_to_emr(
      tracker.tracking_number, 'verified',
      tracker.created_at
    )
    sync_util_service = SyncUtilService.new
    sync_util_service.ack_result_at_facility_level(
      tracker.tracking_number,
      tracker.test_id,
      tracker.created_at,
      2,
      'emr_at_facility'
    )
    ResultSyncTracker.find_by(
      tracking_number: tracker.tracking_number,
      test_id: tracker.test_id
    )&.update(sync_status: true)
  end
end
