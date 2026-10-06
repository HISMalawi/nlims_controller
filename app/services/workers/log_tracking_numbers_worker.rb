# frozen_string_literal: true

##
# Worker for logging central tracking numbers from master NLIMS
class LogTrackingNumbersWorker
  BATCH_SIZE = 50_000

  def run
    return unless Config.local_nlims?

    Rails.logger.info('Starting to log tracking numbers from master NLIMS')

    last_logged_tracking_number = TrackingNumberLogger.maximum(:chsu_tracking_number_order_id)
    chsu_tracking_number_order_id = last_logged_tracking_number || 0

    Rails.logger.info("Last logged tracking number order ID: #{chsu_tracking_number_order_id}")

    nlims_service = NlimsSyncUtilsService.new(nil)
    order_tracking_numbers = nlims_service.order_tracking_numbers(chsu_tracking_number_order_id, limit: BATCH_SIZE)

    Rails.logger.info("Retrieved #{order_tracking_numbers.size} tracking numbers to log")

    processed_count = 0
    order_tracking_numbers.each do |order_tracking_number|
      Rails.logger.debug("Logging tracking number: #{order_tracking_number[:tracking_number]} for order ID: #{order_tracking_number[:id]}")

      TrackingNumberLogger.find_or_create_by(
        tracking_number: order_tracking_number[:tracking_number],
        chsu_tracking_number_order_id: order_tracking_number[:id]
      )

      processed_count += 1
    end

    Rails.logger.info("Successfully logged #{processed_count} tracking numbers")
  rescue StandardError => e
    Rails.logger.error("Error logging tracking numbers: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end
end
