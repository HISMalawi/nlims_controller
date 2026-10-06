# frozen_string_literal: true

class MahisCouchdbResultSyncJob
  include Sidekiq::Job
  sidekiq_options lock: :until_executed,
                  on_conflict: :reject

  def perform(params)
    return false unless MahisCouchdb::Configuration.current.enabled?

    tracking_number, test_id = params.values_at('tracking_number', 'test_id')
    success = MahisCouchdb::ResultWriterService.new.call(tracking_number:, test_id:)
    raise StandardError, "MaHIS CouchDB result sync failed for #{tracking_number}/#{test_id}" unless success

    ResultSyncTracker.where(tracking_number:, test_id:, app: 'emr').last&.update(sync_status: true)
    true
  end
end
