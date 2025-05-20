# frozen_string_literal: true

# IntegrationStatusService
class IntegrationStatusService
  def initialize
    @sites = Site.where(enabled: true,
                        region: 'central').where("host_address <> '' AND host_address IS NOT NULL").limit(5)
  end

  def ping_server(ip_address)
    Net::Ping::External.new(ip_address).ping
  end

  def application_status(ip_address, port)
    url = "http://#{ip_address}:#{port}/api/v1/ping"

    response = RestClient::Request.execute(
      method: :get,
      url: url,
      headers: { content_type: 'application/json' },
      timeout: 5,
      open_timeout: 5
    )

    JSON.parse(response)['ping']
  rescue RestClient::Exceptions::OpenTimeout, RestClient::Exceptions::ReadTimeout => e
    puts "Timeout error: #{e.message}"
    false
  rescue StandardError => e
    puts "Error: #{e.message}"
    false
  end

  def last_sync_date(ip_address, sending_facility)
    tracking_number_hosts = TrackingNumberHost.where("source_host = '#{ip_address}'").limit(5).pluck(:tracking_number)
    specimen = Speciman.where(tracking_number: tracking_number_hosts).order('created_at DESC').first
    specimen&.create_at || Speciman.where(sending_facility: sending_facility).order('created_at DESC').first&.created_at
  end

  def last_sync_date_gt_24hr?(last_sync_date)
    last_sync_date.present? && last_sync_date < 24.hours.ago
  end

  def check_integration_status
    @sites.each do |site|
      ip_address = site.host_address
      sending_facility = site.name
      puts "pinging #{ip_address}"
      ping_status = ping_server(ip_address)
      puts "checking application status #{ip_address}"
      app_status = application_status(ip_address, site.application_port)
      puts "checking last sync date #{ip_address}"
      last_sync_date = last_sync_date(ip_address, sending_facility)
      last_sync_date_gt_24hrs = last_sync_date_gt_24hr?(last_sync_date)
      yield site, ping_status, app_status, last_sync_date_gt_24hrs, last_sync_date
    end
  end

  def collect_outdated_sync_sites
    outdated_sites = []
    check_integration_status do |site, ping_status, app_status, last_sync_date_gt_24hrs, last_sync_date|
      if last_sync_date_gt_24hrs
        outdated_sites << {
          name: site.name,
          ip_address: site.host_address,
          app_port: site.application_port,
          ping_status: ping_status,
          app_status: app_status,
          last_sync_date: last_sync_date.present? ? last_sync_date.strftime('%Y-%m-%d %H:%M:%S') : nil
        }
      end
    end
    outdated_sites
  end
end
