# frozen_string_literal: true

##
# Worker for syncing data from master NLIMS
# Pulls test results and status updates, then pushes to EMR
class MasterNlimsSyncDataWorker
  include NlimsDataProcessor

  def run
    return unless Config.local_nlims?

    Rails.logger.info('Starting master NLIMS data sync')

    tests = TestService.vl_without_results
    Rails.logger.info("Found #{tests.count} tests without results to sync")

    pull_and_process_data(tests)

    Rails.logger.info('Master NLIMS data sync completed successfully')
  rescue StandardError => e
    Rails.logger.error("Error in master NLIMS data sync: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end
end
