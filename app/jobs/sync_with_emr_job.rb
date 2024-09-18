# frozen_string_literal: true

# SyncWithEmrJob job that syncs to emr
class SyncWithEmrJob
  include Sidekiq::Job

  def perform(params)
    tracking_number, status, test_id, time, action = params.values_at('tracking_number', 'status', 'test_id', 'time',
                                                                      'action')
    emr_service = EmrSyncService.new(tracking_number)
    emr_service.push_status_to_emr(tracking_number, status, time, test_id) if action == 'status_update'
    emr_service.push_result_to_emr(tracking_number, test_id, time) if action == 'result_update'
  end
end
