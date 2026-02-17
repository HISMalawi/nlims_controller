# frozen_string_literal: true

# Job to update order source couch IDs
class UpdateOrderSourceCouchIdJob
  include Sidekiq::Job
  sidekiq_options lock: :until_executed,
                  on_conflict: :log,
                  queue: :low_priority

  def perform
    Rails.logger.info('[UpdateOrderSourceCouchIdJob] Starting couch ID updates')

    return unless Config.local_nlims?

    tests = TestService.vl_without_results
    Rails.logger.info("[UpdateOrderSourceCouchIdJob] Found #{tests.count} tests to update")

    mns = NlimsSyncUtilsService.new(nil)

    tests.each do |test|
      Rails.logger.info("[UpdateOrderSourceCouchIdJob] Updating order source couch ID for #{test['tracking_number']}")
      mns.update_order_source_couch_id(
        test['tracking_number'],
        test['sending_facility'],
        test['couch_id']
      )
    rescue StandardError => e
      Rails.logger.error("[UpdateOrderSourceCouchIdJob] Error updating #{test['tracking_number']}: #{e.message}")
    end

    Rails.logger.info('[UpdateOrderSourceCouchIdJob] Completed couch ID updates')
  rescue StandardError => e
    Rails.logger.error("[UpdateOrderSourceCouchIdJob] Error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end
end
