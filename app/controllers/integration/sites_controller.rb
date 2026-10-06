# frozen_string_literal: true

module Integration
  # Per-site integration setup: switch a site between local NLIMS and central EMR monitoring
  class SitesController < BaseController
    before_action :set_site, only: %i[edit update test]

    def index
      @sites = Site.includes(:emr_instance).order(:name)
      @emr_instances = EmrInstance.order(:name)
    end

    def edit
      @emr_instances = EmrInstance.order(:name)
    end

    def update
      @site.assign_attributes(site_params)
      if @site.save
        message = "#{@site.name} saved (#{IntegrationStatusService.mode_label(@site.integration_mode)})."
        if params[:recheck] == '1'
          row = IntegrationStatusService.new.refresh_site(@site)
          message += " Status re-checked: app #{row['app_status'] ? 'Running' : 'Down'}, " \
                     "#{row.dig('order_summary', 'overall_remark')}."
        end
        notify(message)
        redirect_to integration_sites_path
      else
        @emr_instances = EmrInstance.order(:name)
        render :edit, status: :unprocessable_entity
      end
    end

    # Runs a check with the submitted (unsaved) values so a migration can be verified before saving
    def test
      @site.assign_attributes(site_params)
      return render(json: { ok: false, errors: @site.errors.full_messages }) unless @site.valid?

      row = IntegrationStatusService.new.check_site(@site)
      render json: { ok: true, status: row }
    end

    # Queues a full re-check of every enabled site
    def run_check
      GenerateIntegrationStatusReportJob.perform_async
      notify('Full integration status check queued. Results appear on Integrated Sites when it finishes.')
      redirect_to integration_sites_path
    end

    private

    def set_site
      @site = Site.find(params[:id])
    end

    def site_params
      params.require(:site).permit(
        :integration_mode, :emr_instance_id, :mahis_location_id, :mahis_facility_code,
        :other_name, :host_address, :application_port, :enabled
      )
    end
  end
end
