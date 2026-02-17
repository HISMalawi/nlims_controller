# frozen_string_literal: true

# Job to sync acknowledgements for results delivered to sites
class AcknowledgeResultsJob
  include Sidekiq::Job
  sidekiq_options lock: :until_executed,
                  on_conflict: :log,
                  queue: :high_priority

  def perform
    Rails.logger.info('[AcknowledgeResultsJob] Starting acknowledgement sync')

    return unless Config.local_nlims?

    last_date = (Date.today - 6.months).to_s
    receipient_type_id = TestResultRecepientType.find_by(
      name: 'test_results_delivered_to_site_electronically_at_local_nlims_level'
    )&.id

    res = Test.find_by_sql(
      "SELECT specimen.tracking_number as tracking_number, specimen.id as specimen_id,
       tests.id as test_id,test_type_id as test_type_id, test_types.name as test_name, specimen.couch_id as couch_id
       FROM tests INNER JOIN specimen ON specimen.id = tests.specimen_id
       INNER JOIN test_types ON test_types.id = tests.test_type_id
       WHERE tests.test_result_receipent_types = #{receipient_type_id}
       AND DATE(specimen.date_created) > '#{last_date}' AND test_types.name LIKE '%Viral Load%'"
    )

    Rails.logger.info("[AcknowledgeResultsJob] Found #{res.count} tests to acknowledge")

    if res.present?
      pull_and_process_data_master_nlims(res)
      push_acknwoledgement_to_master_nlims
    end

    Rails.logger.info('[AcknowledgeResultsJob] Completed acknowledgement sync')
  rescue StandardError => e
    Rails.logger.error("[AcknowledgeResultsJob] Error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end

  private

  def pull_and_process_data_master_nlims(res)
    nlims_service = NlimsSyncUtilsService.new(nil)

    unless nlims_service.token.present?
      Rails.logger.error('[AcknowledgeResultsJob] NLIMS authentication failed')
      return
    end

    Rails.logger.info('[AcknowledgeResultsJob] NLIMS authentication successful')

    emr_service = EmrSyncService.new(nil)
    emr_auth_status = [emr_service.token.present?, emr_service.token]

    res.each do |test|
      Rails.logger.info("[AcknowledgeResultsJob] Processing test: #{test['tracking_number']}")
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
  end

  def push_acknwoledgement_to_master_nlims
    Rails.logger.info('[AcknowledgeResultsJob] Pushing acknowledgement to master NLIMS')
    nlims = NlimsSyncUtilsService.new(nil)
    nlims.push_acknwoledgement_to_master_nlims
  rescue StandardError => e
    Rails.logger.error("Error in push_acknwoledgement_to_master_nlims: #{e.message}")
  end
end
