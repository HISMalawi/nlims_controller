# frozen_string_literal: true

module Integration
  # Central EMR instances (e.g. MaHIS) that sites can be attached to
  class EmrInstancesController < BaseController
    ENCRYPTION_HELP = 'Encryption keys are not configured. Run `bin/rails db:encryption:init` and put the ' \
                      'keys under active_record_encryption in config/settings.yml (or the ' \
                      'ACTIVE_RECORD_ENCRYPTION_* environment variables), then restart NLIMS.'

    before_action :set_emr_instance, only: %i[edit update destroy]

    def index
      @emr_instances = EmrInstance.order(:name)
      @site_counts = Site.where.not(emr_instance_id: nil).group(:emr_instance_id).count
    end

    def new
      @emr_instance = EmrInstance.new
    end

    def create
      @emr_instance = EmrInstance.new(emr_instance_params)
      save_and_respond(:new)
    end

    def edit; end

    def update
      @emr_instance.assign_attributes(emr_instance_params)
      save_and_respond(:edit)
    end

    def destroy
      if @emr_instance.destroy
        notify("#{@emr_instance.name} deleted.")
      else
        notify("Cannot delete #{@emr_instance.name}: #{@emr_instance.errors.full_messages.to_sentence}. " \
               'Move its sites to another instance or back to local NLIMS first.')
      end
      redirect_to integration_emr_instances_path
    end

    # Checks health, version and login using the values currently in the form (saved password if left blank)
    def test_connection
      instance = params[:id].present? ? EmrInstance.find(params[:id]) : EmrInstance.new
      instance.assign_attributes(emr_instance_params)
      return render(json: { ok: false, errors: instance.errors.full_messages }) unless instance.valid?

      render json: { ok: true, result: IntegrationStatus::EmrInstanceClient.new(instance).test_connection }
    rescue ActiveRecord::Encryption::Errors::Base
      render json: { ok: false, errors: [ENCRYPTION_HELP] }
    end

    private

    def set_emr_instance
      @emr_instance = EmrInstance.find(params[:id])
    end

    def save_and_respond(template)
      if @emr_instance.save
        notify("#{@emr_instance.name} saved.")
        redirect_to integration_emr_instances_path
      else
        render template, status: :unprocessable_entity
      end
    rescue ActiveRecord::Encryption::Errors::Base
      @emr_instance.errors.add(:base, ENCRYPTION_HELP)
      render template, status: :unprocessable_entity
    end

    def emr_instance_params
      permitted = params.require(:emr_instance).permit(
        :name, :emr_type, :base_url, :health_path, :version_path, :login_path, :summary_path,
        :username, :password, :vl_concept_id, :verify_ssl, :timeout_seconds, :active
      )
      # A blank password field means "keep the saved password"
      permitted.delete(:password) if permitted[:password].blank?
      permitted
    end
  end
end
