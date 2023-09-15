file_sites = JSON.parse(File.read(Rails.root.join('db','seed_files','sites.json')))

file_sites.each do |f_site|
    site = Site.where(name: f_site['name'], district: f_site['district']).take
    if !site.nil?
        enabled = site.enabled == true ? true : false
        site.update(host_address: f_site['host_address'], site_code: f_site['site_code'], 
            site_code_number: f_site['site_code_number'],  enabled: enabled
        )
    else
        f_site['enabled'] = false
        Site.create(f_site)
    end
end