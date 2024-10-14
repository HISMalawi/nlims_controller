class HomeController < ApplicationController
  skip_before_action :authenticate_request, only: [:index]

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
  end

  def git_tag
    git_describe = `git describe --tags --abbrev=0`.strip
    git_describe.empty? ? 'No tags available' : git_describe
  end
end
