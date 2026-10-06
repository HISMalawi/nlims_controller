# frozen_string_literal: true

module Integration
  # Global tunables for integration status checks (see IntegrationStatus::Settings)
  class SettingsController < BaseController
    def edit
      @settings = IntegrationStatus::Settings.load
      @errors = []
    end

    def update
      ok, @errors = IntegrationStatus::Settings.save(settings_params.to_h)
      if ok
        notify('Integration status settings saved. They apply from the next check.')
        redirect_to edit_integration_settings_path
      else
        @settings = IntegrationStatus::Settings.new(settings_params.to_h)
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def settings_params
      params.require(:settings).permit(*IntegrationStatus::Settings::DEFAULTS.keys)
    end
  end
end
