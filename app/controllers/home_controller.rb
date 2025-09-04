class HomeController < ApplicationController
  skip_before_action :authenticate_request

  def index
    @info = 'NLIMS SERVICE'
    start_date = Date.today - 1.day
    end_date = Date.today
    concept = { name: 'Viral Load', id: 856 }
    @git_tag = git_tag
    @local_nlims = Config.local_nlims? ? 'Local' : 'Master'
    return unless @local_nlims == 'Local'

    nlims = NlimsSyncUtilsService.new(nil)
    emr = EmrSyncService.new(nil)
    @master_status = nlims.application_status ? 'Running' : 'Down'
    @pinger = Net::Ping::External.new('10.44.0.46').ping ? 'Successful' : 'Cannot be reached'
    @master_auth = nlims.token.blank? ? 'Failed' : 'Successful'
    @nlims_chsu_address = nlims.address
    @emr_auth = emr.token.blank? ? 'Failed' : 'Successful'
    @emr_address = emr.address
    @sidekiq_service_status = SystemctlService.sidekiq_service_status
    @emr_orders = emr.emr_order_summary(start_date, end_date, concept, include_data: false)[:emr]
    nlims_local = OrderService.nlims_local_orders(start_date, end_date, concept)
    @nlims_orders = { count: nlims_local.count, lab_orders: [] }
    @overall_remark = OrderService.order_summary_remark(@emr_orders, @nlims_orders)
  end

  def git_tag
    git_describe = `git describe --tags --abbrev=0`.strip
    git_describe.empty? ? 'No tags available' : git_describe
  end

  def latest_orders_by_site
    @latest_orders_by_site = StatsService.get_latest_orders_by_site
  end

  def latest_results_by_site
    @latest_results_by_site = StatsService.get_latest_results_by_site
  end

  def search_orders
    @orders = StatsService.search_orders(params[:tracking_number])
  end

  def search_results
    @results = StatsService.search_results(params[:tracking_number])
  end

  def counts
    @count_data = StatsService.count_by_sending_facility(params[:from_date], params[:to_date])
  end

  def sites_by_orders
    from = params[:from_date]
    to = params[:to_date]
    sending_facility = params[:sending_facility]
    @sites = StatsService.sites
    @orders_data = StatsService.orders_per_sending_facility(from, to, sending_facility)
  end

  def integrated_sites
    @sites = StatsService.integrated_sites
  end

  def refresh_app_ping_status
    integration_service = IntegrationStatusService.new
    site = Site.find_by(name: params[:site_name])
    status = integration_service.application_status(site&.host_address, site&.application_port)
    ping_status = integration_service.ping_server(site&.host_address)
    timestamp = Time.now.strftime('%d/%b/%Y %H:%M')
    last_sync_date = integration_service.last_sync_date(site&.name)
    last_sync_date = last_sync_date.present? ? last_sync_date.strftime('%d/%b/%Y %H:%M') : 'Has Never Synced with NLIMS'
    order_summary = integration_service.fetch_order_summary(site&.host_address, site&.application_port, site&.name)
    data = {
      "app_status": status[:ping] ? 'Running' : 'Down',
      "ping_status": ping_status ? 'Success' : 'Failed',
      "app_version": status[:version],
      "last_sync_date": last_sync_date,
      "is_gt_24hr": integration_service.last_sync_date_gt_24hr?(last_sync_date),
      "order_summary": order_summary,
      "status_last_updated": timestamp
    }
    report = Report.find_or_create_by(name: 'integration_status') do |r|
      r.data = []
    end

    # Find the site in the existing data array or add it
    site_index = report.data.find_index { |s| s['name'] == params[:site_name] }

    updated_site_data = {
      name: site.name,
      ip_address: site.host_address,
      app_port: site.application_port,
      ping_status: ping_status,
      app_status: status[:ping],
      app_version: status[:version],
      status_last_updated: timestamp,
      last_sync_date_gt_24hr: integration_service.last_sync_date_gt_24hr?(last_sync_date),
      last_sync_date: last_sync_date,
      order_summary: order_summary
    }.stringify_keys

    if site_index
      # Update existing site data
      report.data[site_index] = updated_site_data
    else
      # Add new site data
      report.data << updated_site_data
    end

    report.save!
    render json: data
  end

  def orders_summary
    integration_service = IntegrationStatusService.new
    summary = integration_service.orders_summary(params)
    render json: summary
  end
end
