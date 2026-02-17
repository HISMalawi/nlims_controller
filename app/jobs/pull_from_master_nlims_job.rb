# frozen_string_literal: true

# Job to pull data from master NLIMS
class PullFromMasterNlimsJob
  include Sidekiq::Job
  sidekiq_options lock: :until_executed,
                  on_conflict: :log,
                  queue: :high_priority

  def perform
    Rails.logger.info('[PullFromMasterNlimsJob] Starting data sync from master NLIMS')

    return unless Config.local_nlims?

    res = TestService.vl_without_results
    Rails.logger.info("[PullFromMasterNlimsJob] Found #{res.count} tests without results")

    if res.present?
      pull_and_process_data_master_nlims(res)
      push_acknwoledgement_to_master_nlims
    end

    Rails.logger.info('[PullFromMasterNlimsJob] Completed data sync from master NLIMS')
  rescue StandardError => e
    Rails.logger.error("[PullFromMasterNlimsJob] Error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end

  private

  def pull_and_process_data_master_nlims(res)
    nlims_service = NlimsSyncUtilsService.new(nil)

    unless nlims_service.token.present?
      Rails.logger.error('[PullFromMasterNlimsJob] NLIMS authentication failed')
      return
    end

    Rails.logger.info('[PullFromMasterNlimsJob] NLIMS authentication successful')
    Rails.logger.info("[PullFromMasterNlimsJob] Processing #{res.count} records for status and results syncing")

    emr_service = EmrSyncService.new(nil)
    emr_auth_status = [emr_service.token.present?, emr_service.token]

    res.each do |test|
      Rails.logger.info("[PullFromMasterNlimsJob] Processing test: #{test['tracking_number']}")
      nlims_service.get_results_from_master(
        test['tracking_number'],
        test['specimen_id'],
        test['test_id'],
        test['test_name'],
        emr_auth_status,
        test['couch_id']
      )
    end
  rescue StandardError => e
    Rails.logger.error("Error in pull_and_process_data_master_nlims: #{e.message}")
    raise
  end

  def push_acknwoledgement_to_master_nlims
    Rails.logger.info('[PullFromMasterNlimsJob] Pushing acknowledgement to master NLIMS')
    nlims = NlimsSyncUtilsService.new(nil)
    nlims.push_acknwoledgement_to_master_nlims
  rescue StandardError => e
    Rails.logger.error("Error in push_acknwoledgement_to_master_nlims: #{e.message}")
  end
end
