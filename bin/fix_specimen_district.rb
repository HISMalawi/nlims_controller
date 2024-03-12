# frozen_string_literal: true

puts 'Initiating update...'
sending_facility_districts = Speciman.where("created_at > '2023-09-11' AND district IS NOT NULL")
                                     .group('sending_facility, district').select('DISTINCT sending_facility, district')

sending_facility_districts.each do |send_facility_district|
  puts "Updating district for ==> #{send_facility_district.sending_facility}"
  Speciman.where("sending_facility = '#{send_facility_district.sending_facility}'
  AND district IS NULL AND created_at > '2024-01-01'").update_all(district: send_facility_district.district)
end

missing_districts = [
  {
    sending_facility: 'Mwanza District Hospital',
    district: 'Mwanza'
  },
  {
    sending_facility: 'Lighthouse KCH',
    district: 'Lilongwe'
  }
]
missing_districts.each do |send_facility_district|
  puts "Updating district for ==> #{send_facility_district[:sending_facility]}"
  Speciman.where("sending_facility = '#{send_facility_district[:sending_facility]}'
    AND district IS NULL AND created_at > '2024-01-01'").update_all(district: send_facility_district[:district])
end
puts 'Updating districts done'
