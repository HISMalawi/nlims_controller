# frozen_string_literal: true

require 'parallel'

# IntegrationStatusService
class IntegrationStatusService
  def initialize
    @sites = Site.where(enabled: true)
  end

  def ping_server(ip_address)
    Net::Ping::External.new(ip_address || '').ping
  end

  def application_status(ip_address, port)
    return false if ip_address.blank? || port.blank?

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

  def last_sync_date(sending_facility)
    Speciman.where(sending_facility: sending_facility).order('created_at DESC').first&.created_at
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

    results = []

    site_data.each do |site|
      ip_address = site[:ip_address]
      sending_facility = site[:name]
      application_port = site[:app_port]

      last_sync_date = ActiveRecord::Base.connection_pool.with_connection do
        puts "checking last sync date #{sending_facility} : #{ip_address}"
        last_sync_date(sending_facility)
      end

      next unless last_sync_date_gt_24hr?(last_sync_date)

      puts "pinging #{sending_facility} : #{ip_address}"
      ping_status = ping_server(ip_address)

      puts "checking application status #{sending_facility} : #{ip_address}"
      app_status = application_status(ip_address, application_port)

      results << {
        name: sending_facility,
        ip_address: ip_address,
        app_port: application_port,
        ping_status: ping_status,
        app_status: app_status,
        last_sync_date: last_sync_date.present? ? last_sync_date.strftime('%d/%b/%Y %H:%M') : 'Has Never Synced with NLIMS'
      }
    rescue StandardError => e
      puts "[Error] #{e.class}: #{e.message}"
    end

    results
  end

  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Metrics/AbcSize

  def generate_status_report
    data = check_integration_status.sort_by { |site| site[:name].to_s.downcase }
    Report.find_or_create_by(name: 'integration_status').update(data:)
  end

  def collect_outdated_sync_sites
    report = Report.where(name: 'integration_status').where(updated_at: (Time.now - 6.hour)..Time.now).first
    return report&.data if report.present?

    generate_status_report
    Report.where(name: 'integration_status').where(updated_at: (Time.now - 6.hour)..Time.now).first&.data
  end

  def generate_csv_report(site_reports)
    require 'csv'

    csv_data = CSV.generate do |csv|
      # Add headers
      csv << ['Site', 'IP Address', 'Application Port', 'Application Status', 'Ping Status', 'Last Sync Date']

      # Add data rows
      site_reports.each do |report|
        csv << [
          report['name'],
          report['ip_address'],
          report['app_port'],
          report['app_status'] ? 'Running' : 'Down',
          report['ping_status'] ? 'Successful' : 'Failed',
          report['last_sync_date']
        ]
      end
    end

    # Create a temporary file
    file_path = "tmp/integration_status_report_#{Time.now.strftime('%Y%m%d%H%M%S')}.csv"
    File.write(file_path, csv_data)

    file_path
  end
end
