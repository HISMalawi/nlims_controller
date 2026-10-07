# frozen_string_literal: true

require 'parallel'

# IntegrationStatusService
# Checks each enabled site through the path that matches how it is set up (local NLIMS or central EMR,
# see Site#integration_mode) and stores one uniformly shaped report for the dashboard, the daily email
# and PowerBI.
class IntegrationStatusService
  REPORT_NAME = 'integration_status'
  HISTORY_REPORT_NAME = 'integration_status_history'

  attr_reader :settings

  def initialize(sites: Site.enabled)
    @sites = sites
    @settings = IntegrationStatus::Settings.load
  end

  def check_integration_status
    check_sites(@sites)
  end

  def generate_status_report
    data = check_integration_status.sort_by { |site| site['name'].to_s.downcase }
    Report.find_or_create_by(name: REPORT_NAME).update(data:)
    Report.create(name: HISTORY_REPORT_NAME, data:)
    data
  end

  # Checks a site without saving anything; works on unsaved changes too (used by "Test" in the setup UI)
  def check_site(site)
    check_sites([site]).first
  end

  # Re-checks one site and replaces its row in the stored report
  def refresh_site(site)
    row = check_site(site)
    report = Report.find_or_create_by(name: REPORT_NAME) { |r| r.data = [] }
    data = (report.data || []).reject { |r| r['name'] == site.name } << row
    report.update!(data: data.sort_by { |r| r['name'].to_s.downcase })
    row
  end

  # Runs on a local NLIMS: answers master's request for EMR vs local NLIMS order counts
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
    report = Report.where(name: REPORT_NAME).first
    return [] unless report.present?

    report&.data&.select { |site| site['last_sync_date_gt_24hr'] }
  end

  def generate_csv_report(site_reports)
    require 'csv'

    csv_data = CSV.generate do |csv|
      # Add headers
      csv << ['Site', 'IP Address', 'NLIMS Application Port', 'Last Synced Order Timestamp (CHSU)',
              'Application Status', 'Ping Status', 'App Version', 'App-Ping Status Last Updated At',
              'Integration Mode', 'EMR Instance', 'Orders Summary Remark']

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
          report['status_last_updated'],
          IntegrationStatusService.mode_label(report['integration_mode']),
          report['emr_instance'],
          report.dig('order_summary', 'overall_remark')
        ]
      end
    end

    # Create a temporary file
    file_path = "tmp/integration_status_report_#{Time.now.strftime('%Y%m%d%H%M%S')}.csv"
    File.write(file_path, csv_data)

    file_path
  end

  # Rows written before integration modes existed have no mode; they were all local NLIMS sites
  def self.mode_label(mode)
    mode == Site::CENTRAL_EMR ? 'Central EMR' : 'Local NLIMS'
  end

  private

  def check_sites(sites)
    sites = sites.to_a
    return [] if sites.empty?

    ActiveRecord::Associations::Preloader.new(records: sites, associations: :emr_instance).call
    facts = IntegrationStatus::SiteFacts.prefetch(sites, settings)
    clients = sites.filter_map(&:emr_instance).select(&:active).uniq(&:id)
                   .to_h { |instance| [instance.id, IntegrationStatus::EmrInstanceClient.new(instance)] }
    checkers = sites.map { |site| checker_for(site, facts, clients) }
    run_checkers(checkers)
  end

  def checker_for(site, facts, clients)
    if site.central_emr?
      IntegrationStatus::CentralEmrChecker.new(site:, settings:, facts:, client: clients[site.emr_instance_id])
    else
      IntegrationStatus::LocalNlimsChecker.new(site:, settings:, facts:)
    end
  end

  # Checkers only do network I/O (all DB reads happen in SiteFacts), so threads don't need DB connections
  def run_checkers(checkers)
    threads = [settings.parallel_threads, checkers.size].min
    return checkers.map(&:call) if threads <= 1

    ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
      Parallel.map(checkers, in_threads: threads) do |checker|
        Rails.application.executor.wrap { checker.call }
      end
    end
  end
end
