class HomeController < ApplicationController
  skip_before_action :authenticate_request

  def index
    @info = 'NLIMS SERVICE'
    settings = IntegrationStatus::Settings.load
    start_date = settings.summary_start_date
    end_date = settings.summary_end_date
    concept = settings.concept
    @git_tag = git_tag
    @local_nlims = Config.local_nlims? ? 'Local' : 'Master'
    return unless @local_nlims == 'Local'

    nlims = NlimsSyncUtilsService.new(nil)
    emr = EmrSyncService.new(nil)
    @master_status = nlims.application_status ? 'Running' : 'Down'
    @pinger = Net::Ping::External.new(master_host(nlims.address)).ping ? 'Successful' : 'Cannot be reached'
    @master_auth = nlims.token.blank? ? 'Failed' : 'Successful'
    @nlims_chsu_address = nlims.address
    @emr_auth = emr.token.blank? ? 'Failed' : 'Successful'
    @emr_address = emr.address
    @sidekiq_service_status = SystemctlService.sidekiq_service_status
    @emr_orders = emr.emr_order_summary(start_date, end_date, concept, include_data: false)&.dig(:emr)
    @emr_orders ||= { count: 0, last_order_date: nil, lab_orders: [], remark: 'EMR Not Reachable/ERROR Fetching EMR Orders Summary' }
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
    site = Site.find_by(name: params[:site_name])
    return render(json: { error: 'Site not found' }, status: :not_found) if site.nil?

    row = IntegrationStatusService.new.refresh_site(site)
    render json: {
      app_status: row['app_status'] ? 'Running' : 'Down',
      ping_status: row['ping_status'] ? 'Success' : 'Failed',
      app_version: row['app_version'],
      last_sync_date: row['last_sync_date'],
      is_gt_24hr: row['last_sync_date_gt_24hr'],
      order_summary: row['order_summary'],
      status_last_updated: row['status_last_updated'],
      integration_mode: row['integration_mode'],
      ip_address: row['ip_address'],
      app_port: row['app_port'],
      check_errors: row['check_errors']
    }
  end

  def orders_summary
    integration_service = IntegrationStatusService.new
    summary = integration_service.orders_summary(params)
    render json: summary
  end

  private

  def master_host(address)
    URI.parse(address.to_s).host || address
  rescue URI::InvalidURIError
    address
  end
end
