# frozen_string_literal: true

last_logged_tracking_number = TrackingNumberLogger.last

chsu_tracking_number_order_id = last_logged_tracking_number&.chsu_tracking_number_order_id || 0

nlims_service = NlimsSyncUtilsService.new(nil)
order_tracking_numbers = nlims_service.order_tracking_numbers(chsu_tracking_number_order_id, limit: 1000)
order_tracking_numbers.each do |order_tracking_number|
  TrackingNumberLogger.create!(
    tracking_number: order_tracking_number[:tracking_number],
    chsu_tracking_number_order_id: order_tracking_number[:id]
  )
end
