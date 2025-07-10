class HomeController < ApplicationController
  skip_before_action :authenticate_request

  def index
    @info = 'NLIMS SERVICE'
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
end
