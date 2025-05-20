# frozen_string_literal: true

require 'parallel'

# IntegrationStatusService
class IntegrationStatusService
  def initialize
    @sites = Site.where(enabled: true, region: 'central').where("host_address <> '' AND host_address IS NOT NULL")
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
      timeout: 10,
      open_timeout: 10
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
    last_sync_date.present? ? last_sync_date < 24.hours.ago : true
  end

  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/AbcSize
  def check_integration_status
    site_data = @sites.map do |site|
      {
        name: site.name,
        ip_address: site.host_address,
        app_port: site.application_port
      }
    end

    Parallel.map(site_data, in_threads: 4, finish: ->(item, i, result) {}) do |site|
      ip_address = site[:ip_address]
      sending_facility = site[:name]
      application_port = site[:app_port]

      last_sync_date = ActiveRecord::Base.connection_pool.with_connection do
        puts "checking last sync date #{ip_address}"
        last_sync_date(ip_address, sending_facility)
      end

      next unless last_sync_date_gt_24hr?(last_sync_date)

      puts "pinging #{ip_address}"
      ping_status = ping_server(ip_address)

      puts "checking application status #{ip_address}"
      app_status = application_status(ip_address, application_port)
      {
        name: sending_facility,
        ip_address: ip_address,
        app_port: application_port,
        ping_status: ping_status,
        app_status: app_status,
        last_sync_date: last_sync_date&.strftime('%Y-%m-%d %H:%M:%S')
      }
    rescue StandardError => e
      puts "[Parallel Error] #{e.class}: #{e.message}"
      nil
    end.compact
  end
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Metrics/AbcSize

  def collect_outdated_sync_sites
    check_integration_status.sort_by { |site| site[:name].to_s.downcase }
  end
end
