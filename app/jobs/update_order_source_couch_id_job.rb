# frozen_string_literal: true

##
# Background job to update order source couch IDs
# Scheduled to run once a week on Friday at 3pm
class UpdateOrderSourceCouchIdJob
  include Sidekiq::Job
  sidekiq_options lock: :until_executed,
                  on_conflict: :reject,
                  retry: 3

  def perform
    return unless Config.local_nlims?

    Rails.logger.info('[UpdateOrderSourceCouchIdJob] Starting order source couch ID update')

    worker = UpdateOrderSourceCouchIdWorker.new
    worker.run

    Rails.logger.info('[UpdateOrderSourceCouchIdJob] Completed order source couch ID update')
  rescue StandardError => e
    Rails.logger.error("[UpdateOrderSourceCouchIdJob] Error: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end
end
