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
    json_parse = JSON.parse(response)
    {
      ping: json_parse['ping'],
      version: json_parse['version'].present? ? json_parse['version'] : 'N/A'
    }
  rescue RestClient::Exceptions::OpenTimeout, RestClient::Exceptions::ReadTimeout => e
    puts "Timeout error: #{e.message}"
    { ping: false, version: 'N/A' }
  rescue RestClient::ExceptionWithResponse => e
    if e.http_code == 404
      url = "http://#{ip_address}:#{port}/api/v1/re_authenticate/aexede/aexede"
      response = RestClient::Request.execute(
        method: :get,
        url: url,
        headers: { content_type: 'application/json' },
        timeout: 10,
        open_timeout: 10
      )
      json_parse = JSON.parse(response)
      { ping: json_parse['error'], version: 'N/A' }
    end
  rescue StandardError => e
    puts "Error: #{e.message}"
    { ping: false, version: 'N/A' }
  end

  def last_sync_date(sending_facility)
    Speciman.where(sending_facility: sending_facility).order('created_at DESC').first&.created_at
  end

  def last_sync_date_gt_24hr?(last_sync_date)
    last_sync_date.present? ? last_sync_date < 48.hours.ago : true
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

      # next unless last_sync_date_gt_24hr?(last_sync_date)

      puts "pinging #{sending_facility} : #{ip_address}"
      ping_status = ping_server(ip_address)

      puts "checking application status #{sending_facility} : #{ip_address}"
      status = application_status(ip_address, application_port)
      order_summary = fetch_order_summary(ip_address, application_port, sending_facility)

      results << {
        name: sending_facility,
        ip_address: ip_address,
        app_port: application_port,
        ping_status: ping_status,
        app_status: status[:ping],
        app_version: status[:version],
        status_last_updated: Time.now.strftime('%d/%b/%Y %H:%M'),
        last_sync_date_gt_24hr: last_sync_date_gt_24hr?(last_sync_date),
        last_sync_date: last_sync_date.present? ? last_sync_date.strftime('%d/%b/%Y %H:%M') : 'Has Never Synced with NLIMS',
        order_summary: order_summary
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

  def fetch_order_summary(ip_address, port, sending_facility)
    url = "http://#{ip_address}:#{port}/orders_summary"
    include_data = false
    payload = {
      start_date: Date.today - 1.day,
      end_date: Date.today,
      concept: { name: 'Viral Load', id: 856 },
      include_data: include_data
    }
    response = RestClient::Request.execute(
      method: :get,
      url: url,
      payload: payload.to_json,
      headers: { content_type: 'application/json' },
      timeout: 10,
      open_timeout: 10
    )
    data = JSON.parse(response).deep_symbolize_keys
    nlims_chsu = OrderService.nlims_local_orders(payload[:start_date], payload[:end_date], payload[:concept], sending_facility: sending_facility)
    data[:nlims_chsu] = {
      count: nlims_chsu.count,
      lab_orders: include_data ? nlims_chsu.pluck(:tracking_number).uniq : []
    }
    data[:overall_remark] = OrderService.order_summary_remark(data[:emr], data[:nlims_local], nlims_chsu: data[:nlims_chsu])
    data
  rescue StandardError => e
    puts "Error: #{e.message}"
    {
      "emr": {
        "count": 0,
        "lab_orders": [],
        "remark": 'NLIMS Local Not Reachable'
      },
      "nlims_local": {
        "count": 0,
        "lab_orders": []
      },
      "nlims_chsu": { "count": 0, "lab_orders": [] },
      "overall_remark": 'NLIMS Local Not Reachable'
    }
  end

  def orders_summary(params)
    emr = EmrSyncService.new(nil)
    include_data = params[:include_data]
    summary = emr.emr_order_summary(params[:start_date], params[:end_date], params[:concept],
                                    include_data: include_data)
    nlims_local = OrderService.nlims_local_orders(params[:start_date], params[:end_date], params[:concept])
    summary[:nlims_local] =
      { count: nlims_local.count, lab_orders: include_data ? nlims_local.pluck(:tracking_number).uniq : [] }
    summary[:overall_remark] = OrderService.order_summary_remark(summary[:emr], summary[:nlims_local])
    summary
  end

  def collect_outdated_sync_sites
    report = Report.where(name: 'integration_status').where(updated_at: (Time.now - 6.hour)..Time.now).first
    return report&.data&.select { |site| site['last_sync_date_gt_24hr'] } if report.present?

    generate_status_report
    data = Report.where(name: 'integration_status').where(updated_at: (Time.now - 6.hour)..Time.now).first&.data
    data&.select { |site| site['last_sync_date_gt_24hr'] } if data.present?
  end

  def generate_csv_report(site_reports)
    require 'csv'

    csv_data = CSV.generate do |csv|
      # Add headers
      csv << ['Site', 'IP Address', 'NLIMS Application Port', 'Last Synced Order Timestamp (CHSU)',
              'Application Status', 'Ping Status', 'App Version', 'App-Ping Status Last Updated At']

      # Add data rows
      site_reports.each do |report|
        csv << [
          report['name'],
          report['ip_address'],
          report['app_port'],
          report['last_sync_date'],
          report['app_status'] ? 'Running' : 'Down',
          report['ping_status'] ? 'Successful' : 'Failed',
          report['app_version'],
          report['status_last_updated']
        ]
      end
    end

    # Create a temporary file
    file_path = "tmp/integration_status_report_#{Time.now.strftime('%Y%m%d%H%M%S')}.csv"
    File.write(file_path, csv_data)

    file_path
  end
end
