# frozen_string_literal: true

host_address = '10.10.10.10' # Replace with the actual host address
start_date = Date.new(2025, 12, 13)
district = 'xxxxx' # Replace with the actual district
puts "Fixing #{district} orders to have correct sending facility..."
tracking_numbers = TrackingNumberHost.where(source_host: host_address,
                                            created_at: start_date..).pluck(:tracking_number)
Speciman.where(tracking_number: tracking_numbers, district: district).update_all(
  sending_facility: Site.find_by(host_address: host_address).name
)
puts "Updated orders for #{district} and IP: #{host_address}"
puts 'Done'
