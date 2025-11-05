# frozen_string_literal: true

# SyncWithEmrJob job that syncs to emr
class SyncWithEmrJob
  include Sidekiq::Job
  sidekiq_options lock: :until_executed,
                  on_conflict: :reject

  def perform(params)
    tracking_number, status, test_id, action = params.values_at('tracking_number', 'status', 'test_id', 'action')
    emr_service = EmrSyncService.new(tracking_number)
    if action == 'status_update'
      time = StatusSyncTracker.find_by(tracking_number:, test_id:, status:, app: 'emr')&.time_updated
      emr_service.push_status_to_emr(tracking_number, status, time, test_id)
    elsif action == 'result_update'
      time = ResultSyncTracker.where(tracking_number:, test_id:, app: 'emr').last&.created_at
      emr_service.push_result_to_emr(tracking_number, test_id, time)
    end
  end
end
