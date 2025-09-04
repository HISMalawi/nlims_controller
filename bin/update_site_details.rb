# frozen_string_literal: true

# This script updates the site details in the database.
json_file = JSON.parse(File.read('db/seed_files/updated_sites.json'))
json_file.each do |site|
  existing_site = Site.find_by(id: site['id'], district: site['district'])
  if existing_site
    existing_site.update!(site)
  else
    Site.create!(site)
  end
end
