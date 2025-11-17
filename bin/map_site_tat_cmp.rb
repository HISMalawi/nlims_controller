# frozen_string_literal: true

require 'csv' # Load CSV library

site_vl_path = Rails.root.join('site_vl_data.csv') # Define path to CSV file

# Load and normalize CSV data
site_vl_data = CSV.read(site_vl_path, headers: true).map do |row|
  row.to_h.transform_keys(&:strip)
end

# Extract valid turnaround times
def calculate_tat(record)
  puts record['Date received']
  return nil unless record['Order Date'].present? &&
                    record['Date received'].present? &&
                    record['Mode of Delivery'] == 'Electronic' &&
                    !['2-Sep-25', '3-Oct-25', '4-Sep-25', '27-Oct-25', '29-Oct-25'].include?(record['Date received'])

  order_date = Date.parse(record['Order Date'])
  received_date = Date.parse(record['Date received'])
  (received_date - order_date).to_i
rescue ArgumentError
  nil
end

tats = site_vl_data.filter_map { |record| calculate_tat(record) }

puts "Number of records: #{site_vl_data.length}"
puts "Number of valid TAT records: #{tats.length}"
# Display results
if tats.any?
  average_tat = (tats.sum.to_f / tats.size).round
  puts "✅ Overall Average TAT(from Order Date and Date Received): #{average_tat} days"
else
  puts '⚠️ No valid TAT records found.'
end

rows = CSV.read(site_vl_path, headers: true).map { |r| r.to_h.transform_keys(&:strip) }

tats = rows.map { |r| r['TAT(Days)'].to_f if r['TAT(Days)'].present? && r['Mode of Delivery'] == 'Electronic' }.compact

if tats.any?
  average_tat = tats.sum / tats.size
  puts "✅ Overall Average TAT(from CSV Using TAT Column): #{average_tat.round} days"
else
  puts '⚠️ No valid TAT values found.'
end
