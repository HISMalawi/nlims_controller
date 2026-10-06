# frozen_string_literal: true

##
# Worker for updating order source couch IDs
# Updates the CouchDB document IDs for orders that don't have results
class UpdateOrderSourceCouchIdWorker
  def run
    return unless Config.local_nlims?

    Rails.logger.info('Starting order source couch ID update')

    tests = TestService.vl_without_results
    Rails.logger.info("Found #{tests.count} tests to update")

    processed_count = 0
    tests.each do |test|
      update_order_source_couch_id(test)
      processed_count += 1
    end

    Rails.logger.info("Successfully updated #{processed_count} order source couch IDs")
  rescue StandardError => e
    Rails.logger.error("Error updating order source couch IDs: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end

  private

  def update_order_source_couch_id(test)
    tracking_number = test['tracking_number']
    sending_facility = test['sending_facility']
    couch_id = test['couch_id']

    Rails.logger.info("Updating order source couch ID for #{tracking_number}")

    mns = NlimsSyncUtilsService.new(nil)
    mns.update_order_source_couch_id(tracking_number, sending_facility, couch_id)

    Rails.logger.debug("Updated order source couch ID for #{tracking_number}")
  rescue StandardError => e
    Rails.logger.error("Error updating order source couch ID for #{tracking_number}: #{e.message}")
  end
end
