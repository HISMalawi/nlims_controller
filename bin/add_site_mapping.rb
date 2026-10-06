# frozen_string_literal: true

# Site mapping for other names of sites
site_map = [
  {
    name: 'Area 18 Urban Health Centre',
    district: 'Lilongwe',
    other_name: 'Area 18 Health Centre',
    mahis_location_id: 8,
    mahis_facility_code: 'LL040033'
  }
]

puts 'Starting site mapping process...'
site_map.each do |site|
  puts "Processing site mapping for: #{site[:name]} (Other Name: #{site[:other_name]})"
  existing_site = Site.find_by(name: site[:name], district: site[:district])
  existing_site ||= Site.find_by(other_name: site[:other_name], district: site[:district])
  if existing_site
    existing_site.update(site)
  else
    Site.create(site)
  end
  puts "Updating Order records for site: #{site[:name]} (Other Name: #{site[:other_name]})"
  Speciman.where(sending_facility: site[:other_name], district: site[:district]).update_all(sending_facility: site[:name])
end
puts 'Site mapping process completed.'
