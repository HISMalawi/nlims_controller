# frozen_string_literal: true

# Job to log tracking numbers from central NLIMS
class LogTrackingNumbersJob
  include Sidekiq::Job
  sidekiq_options lock: :until_executed,
                  on_conflict: :log,
                  queue: :default

  def perform
    Rails.logger.info('[LogTrackingNumbersJob] Starting to log tracking numbers')

    return unless Config.local_nlims?

    last_logged_tracking_number = TrackingNumberLogger.maximum(:chsu_tracking_number_order_id)
    chsu_tracking_number_order_id = last_logged_tracking_number || 0

    nlims_service = NlimsSyncUtilsService.new(nil)
    order_tracking_numbers = nlims_service.order_tracking_numbers(chsu_tracking_number_order_id, limit: 50_000)

    Rails.logger.info("[LogTrackingNumbersJob] Found #{order_tracking_numbers.size} tracking numbers to log")

    order_tracking_numbers.each do |order_tracking_number|
      Rails.logger.info("Logging tracking number: #{order_tracking_number[:tracking_number]} for order ID: #{order_tracking_number[:id]}")
      TrackingNumberLogger.find_or_create_by(
        tracking_number: order_tracking_number[:tracking_number],
        chsu_tracking_number_order_id: order_tracking_number[:id]
      )
    end

    Rails.logger.info('[LogTrackingNumbersJob] Completed logging tracking numbers')
  rescue StandardError => e
    Rails.logger.error("[LogTrackingNumbersJob] Error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end
end
