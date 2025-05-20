#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require_relative '../config/environment'

# Load the two CSV files
sites_nlims_path = File.join(Rails.root, 'public', 'sites', 'sites_nlims.csv')
central_poc_path = File.join(Rails.root, 'public', 'sites', 'Sites.csv')
updated_sites_path = File.join(Rails.root, 'public', 'sites', 'updated_sites.csv')
skipped_facilities_path = File.join(Rails.root, 'public', 'sites', 'skipped_facilities.csv')

# Check if files exist
unless File.exist?(sites_nlims_path)
  puts "Error: sites_nlims.csv not found at #{sites_nlims_path}"
  exit 1
end

unless File.exist?(central_poc_path)
  puts "Error: Sites.csv not found at #{central_poc_path}"
  exit 1
end

puts "Loading sites_nlims.csv from #{sites_nlims_path}"
sites_nlims = CSV.read(sites_nlims_path, headers: true)
puts "Loaded #{sites_nlims.count} sites from sites_nlims.csv"

puts "Loading Sites.csv from #{central_poc_path}"
central_poc = CSV.read(central_poc_path, headers: true)
puts "Loaded #{central_poc.count} facilities from Sites.csv"

# Verify column headers
puts "sites_nlims.csv headers: #{sites_nlims.headers.join(', ')}"
puts "Sites.csv headers: #{central_poc.headers.join(', ')}"

# Create a lookup hash from CentralPocSite.csv
ip_lookup = {}
central_poc_facilities = []

# Check if expected columns exist in central_poc
unless central_poc.headers.include?('District') && central_poc.headers.include?('Facility') && central_poc.headers.include?('EMRS')
  puts 'Error: Sites.csv is missing required columns. Expected: District, Facility, EMRS'
  puts "Found: #{central_poc.headers.join(', ')}"
  exit 1
end

central_poc.each do |row|
  next unless row['District'] && row['Facility'] && row['EMRS']

  district = row['District'].downcase
  facility = row['Facility'].downcase
  ip_address = row['EMRS']

  # Skip empty IP addresses
  next if ip_address.nil? || ip_address.strip.empty?

  # Store facility info for tracking skipped facilities
  central_poc_facilities << {
    district: row['District'],
    facility: row['Facility'],
    ip_address: ip_address,
    used: false
  }

  # Create a key for lookup - both with and without case sensitivity
  key = "#{district}|#{facility}"
  ip_lookup[key] = ip_address

  # Also store with original case for exact string matching
  exact_key = "#{row['District']}|#{row['Facility']}"
  ip_lookup["exact|#{exact_key}"] = ip_address
end

puts "Created lookup table with #{ip_lookup.size} entries"
puts 'Sample lookup entries:'
ip_lookup.keys.first(5).each do |key|
  puts "  #{key} => #{ip_lookup[key]}"
end

# Function to normalize facility names for better matching
def normalize_name(name)
  return '' if name.nil?

  name.downcase
      .gsub(/\bhospital\b/, '')
      .gsub(/\bhealth cent(er|re)\b/, '')
      .gsub(/\bclinic\b/, '')
      .gsub(/\burban\b/, '')
      .gsub(/\bdistrict\b/, '')
      .gsub(/\bmission\b/, '')
      .gsub(/\brural\b/, '')
      .strip
end

# Update sites_nlims with IP addresses
updates_count = 0
db_updates_count = 0
updated_sites = []

# Check if expected columns exist in sites_nlims
unless sites_nlims.headers.include?('name') && sites_nlims.headers.include?('district') && sites_nlims.headers.include?('host_address')
  puts 'Error: sites_nlims.csv is missing required columns. Expected: name, district, host_address'
  puts "Found: #{sites_nlims.headers.join(', ')}"
  exit 1
end

# Count sites that need updating
empty_host_count = sites_nlims.count { |site| site['host_address'].to_s.empty? }
puts "Found #{empty_host_count} sites with empty host_address"

# Print some sample sites for debugging
puts 'Sample sites from sites_nlims.csv:'
sites_nlims.first(5).each do |site|
  puts "  #{site['name']} (#{site['district']}) - host_address: '#{site['host_address']}'"
end

sites_nlims.each do |site|
  site_name = site['name']
  site_district = site['district']

  next if site_name.nil? || site_district.nil? || site_name == 'xxx'

  # Debug info
  puts "Trying to match: #{site_name} (#{site_district})" if site['host_address'].to_s.empty?

  # Try exact match first (case insensitive)
  exact_key = "#{site_district.downcase}|#{site_name.downcase}"
  if ip_lookup[exact_key] && site['host_address'].to_s.empty?
    site['host_address'] = ip_lookup[exact_key]
    updates_count += 1
    updated_sites << {
      id: site['id'],
      name: site_name,
      district: site_district,
      ip_address: ip_lookup[exact_key],
      match_type: 'exact'
    }

    # Mark this facility as used
    central_poc_facilities.each do |facility|
      if facility[:district].downcase == site_district.downcase &&
         facility[:facility].downcase == site_name.downcase
        facility[:used] = true
      end
    end

    puts "Exact match found: #{site_name} (#{site_district}) -> #{ip_lookup[exact_key]}"
    next
  end

  # Try exact string match (case sensitive)
  central_poc_facilities.each do |facility|
    exact_key = "exact|#{facility[:district]}|#{facility[:facility]}"

    next unless facility[:district] == site_district &&
                facility[:facility] == site_name &&
                ip_lookup[exact_key] &&
                site['host_address'].to_s.empty?

    site['host_address'] = facility[:ip_address]
    updates_count += 1
    updated_sites << {
      id: site['id'],
      name: site_name,
      district: site_district,
      ip_address: facility[:ip_address],
      match_type: 'exact_case_sensitive'
    }

    facility[:used] = true
    puts "Case-sensitive match: #{site_name} (#{site_district}) -> #{facility[:ip_address]}"
    next
  end

  # Try partial matching
  normalized_site_name = normalize_name(site_name)

  ip_lookup.each do |key, ip|
    next if key.start_with?('exact|') # Skip the exact match keys

    district, facility = key.split('|')
    normalized_facility = normalize_name(facility)

    # Check if district matches and facility names have significant overlap
    next unless district == site_district.downcase &&
                (normalized_facility.include?(normalized_site_name) ||
                 normalized_site_name.include?(normalized_facility)) && site['host_address'].to_s.empty?

    site['host_address'] = ip
    updates_count += 1
    updated_sites << {
      id: site['id'],
      name: site_name,
      district: site_district,
      ip_address: ip,
      match_type: 'partial',
      matched_with: facility
    }

    # Mark this facility as used
    central_poc_facilities.each do |facility_info|
      if facility_info[:district].downcase == district &&
         facility_info[:facility].downcase == facility
        facility_info[:used] = true
      end
    end

    puts "Partial match: #{site_name} (#{site_district}) with #{facility} (#{district}) -> #{ip}"
    break
  end
end

# Write updated data back to sites_nlims.csv
CSV.open(sites_nlims_path, 'w') do |csv|
  csv << sites_nlims.headers
  sites_nlims.each do |row|
    csv << row
  end
end

# Write updated sites to a separate CSV file
CSV.open(updated_sites_path, 'w') do |csv|
  csv << ['ID', 'Name', 'District', 'IP Address', 'Match Type', 'Matched With']
  updated_sites.each do |site|
    csv << [site[:id], site[:name], site[:district], site[:ip_address], site[:match_type], site[:matched_with]]
  end
end

# Write skipped facilities to a separate CSV file
skipped_facilities = central_poc_facilities.reject { |facility| facility[:used] }
CSV.open(skipped_facilities_path, 'w') do |csv|
  csv << ['District', 'Facility', 'IP Address', 'Reason']
  skipped_facilities.each do |facility|
    csv << [facility[:district], facility[:facility], facility[:ip_address],
            'No matching site found in sites_nlims.csv']
  end
end

# Print some sample skipped facilities for debugging
puts 'Sample skipped facilities:'
skipped_facilities.first(5).each do |facility|
  puts "  #{facility[:facility]} (#{facility[:district]}) - IP: #{facility[:ip_address]}"

  # Try to find similar sites in sites_nlims
  similar_sites = sites_nlims.select do |site|
    site['district'].to_s.downcase == facility[:district].downcase &&
      (normalize_name(site['name']).include?(normalize_name(facility[:facility])) ||
       normalize_name(facility[:facility]).include?(normalize_name(site['name'])))
  end

  if similar_sites.any?
    puts '    Similar sites found in sites_nlims.csv:'
    similar_sites.each do |site|
      puts "      #{site['name']} (#{site['district']}) - host_address: '#{site['host_address']}'"
    end
  else
    puts '    No similar sites found in sites_nlims.csv'
  end
end

# Update database records
puts 'Updating database records...'
updated_sites.each do |updated_site|
  # Find the site in the database
  db_site = Site.where(name: updated_site[:name], district: updated_site[:district]).first

  if db_site
    # Update the site with new information
    db_site.update(
      host_address: updated_site[:ip_address],
      application_port: '3009',
      enabled: true
    )

    db_updates_count += 1
    puts "Updated database record for #{updated_site[:name]} (#{updated_site[:district]})"
  else
    puts "Warning: Could not find site in database: #{updated_site[:name]} (#{updated_site[:district]})"
  end
end

puts "Updated #{updates_count} sites with IP addresses from CentralPocSite.csv"
puts "Updated #{db_updates_count} site records in the database"
puts "List of updated sites saved to #{updated_sites_path}"
puts "List of #{skipped_facilities.count} skipped facilities saved to #{skipped_facilities_path}"
