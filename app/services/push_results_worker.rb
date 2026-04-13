# frozen_string_literal: true

##
# Worker for pushing status updates and results to NLIMS
class PushResultsWorker
  def run
    Rails.logger.info('Starting status and results push to NLIMS')

    push_status_updates
    push_results

    Rails.logger.info('Status and results push completed successfully')
  rescue StandardError => e
    Rails.logger.error("Error pushing status/results: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end

  private

  def push_status_updates
    Rails.logger.info('Pushing Status Updates to NLIMS')
    SyncToNlimsService.push_status_to_nlims
  rescue StandardError => e
    Rails.logger.error("Error pushing status updates: #{e.message}")
  end

  def push_results
    Rails.logger.info('Pushing Results to NLIMS')
    SyncToNlimsService.push_result_to_nlims
  rescue StandardError => e
    Rails.logger.error("Error pushing results: #{e.message}")
  end
end
