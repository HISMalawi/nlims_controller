# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Integration setup pages', type: :request do
  let(:admin_role) { Role.find_or_create_by!(name: 'admin') }
  let(:admin) { create_user('integration_admin', roles: [admin_role]) }
  let(:instance) do
    EmrInstance.create!(name: 'MaHIS Central', base_url: 'https://mahis.example.test', username: 'nlims',
                        password: 'secret', vl_concept_id: 10_532)
  end
  let!(:site) do
    Site.create!(name: 'Area 18 Urban Health Centre', district: 'Lilongwe', enabled: true,
                 host_address: '10.0.0.5', application_port: '3010')
  end

  before(:all) do
    ActiveRecord::Encryption.configure(primary_key: 'test-primary-key-0123456789abcdef',
                                       deterministic_key: 'test-deterministic-key-0123456789',
                                       key_derivation_salt: 'test-salt-0123456789abcdef')
  end

  def create_user(username, roles:)
    user = User.create!(username:, password: BCrypt::Password.create('pass123'), app_name: 'NLIMS',
                        partner: 'EGPAF', location: 'CHSU')
    user.roles = roles
    user
  end

  # Browsers can only POST; Rails forms send PATCH/DELETE as a `_method` field (needs Rack::MethodOverride)
  def form_submit(method, path, params = {})
    post path, params: params.merge(_method: method)
  end

  def login(user, password: 'pass123')
    post integration_login_path, params: { username: user.username, password: }
  end

  it 'sends visitors to the login page' do
    get integration_sites_path
    expect(response).to redirect_to(integration_login_path)
  end

  it 'refuses users without the admin role' do
    login(create_user('plain_user', roles: []))
    expect(response).to have_http_status(:unprocessable_entity)
    get integration_sites_path
    expect(response).to redirect_to(integration_login_path)
  end

  it 'refuses a wrong password' do
    login(admin, password: 'wrong')
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'shows central EMR sites on the integrated sites dashboard' do
    site.update!(integration_mode: 'central_emr', emr_instance: instance, mahis_location_id: 8, name: "St. Mary's Clinic")
    Report.create!(name: 'integration_status', data: [{
                     'name' => "St. Mary's Clinic", 'integration_mode' => 'central_emr', 'app_status' => true,
                     'ping_status' => true, 'app_version' => 'v2.1.0', 'check_errors' => [],
                     'order_summary' => { 'emr' => { 'count' => 4 }, 'nlims_local' => { 'count' => 4, 'applicable' => false },
                                          'nlims_chsu' => { 'count' => 4 }, 'overall_remark' => 'All orders drawn in EMR are synched to NLIMS' }
                   }])
    get integrated_sites_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Central EMR', 'mahis.example.test', 'data-site-name="St. Mary&#39;s Clinic"')
    expect(response.body).not_to include('awaiting re-check')
  end

  it 'rejects form posts without a CSRF token' do
    ActionController::Base.allow_forgery_protection = true
    expect { login(admin) }.to raise_error(ActionController::InvalidAuthenticityToken)
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  it 'is not available on a local NLIMS' do
    Config.create!(config_type: 'nlims_host', configs: { local_nlims: true })
    get integration_sites_path
    expect(response).to have_http_status(:forbidden)
  end

  context 'when signed in as an admin' do
    before { login(admin) }

    it 'lists sites' do
      get integration_sites_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Area 18 Urban Health Centre', 'Local NLIMS')
    end

    it 'moves a site to the central EMR' do
      form_submit :patch, integration_site_path(site), {
        site: { integration_mode: 'central_emr', emr_instance_id: instance.id, mahis_location_id: 8,
                mahis_facility_code: 'LL040033', other_name: 'Area 18 Health Centre' }
      }

      expect(response).to redirect_to(integration_sites_path)
      site.reload
      expect(site).to have_attributes(integration_mode: 'central_emr', emr_instance_id: instance.id,
                                      mahis_location_id: 8, other_name: 'Area 18 Health Centre')
      expect(site.integration_mode_changed_at).to be_present
      expect(site.versions.last.whodunnit).to eq(admin.id.to_s)
    end

    it 'requires an instance and location for central EMR sites' do
      form_submit :patch, integration_site_path(site), { site: { integration_mode: 'central_emr', mahis_location_id: '' } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('Central EMR instance must be selected', 'MaHIS location ID is required')
      expect(site.reload.integration_mode).to eq('local_nlims')
    end

    it 'tests unsaved settings without saving them' do
      allow_any_instance_of(IntegrationStatusService).to receive(:check_site) do |_service, checked|
        { 'name' => checked.name, 'integration_mode' => checked.integration_mode }
      end
      post test_integration_site_path(site), params: {
        site: { integration_mode: 'central_emr', emr_instance_id: instance.id, mahis_location_id: 8 }
      }, as: :json

      expect(response.parsed_body).to eq('ok' => true, 'status' => { 'name' => site.name, 'integration_mode' => 'central_emr' })
      expect(site.reload.integration_mode).to eq('local_nlims')
    end

    it 'creates an EMR instance with an encrypted password' do
      post integration_emr_instances_path, params: {
        emr_instance: { name: 'MaHIS', base_url: 'https://mahis.health.gov.mw/', username: 'nlims', password: 's3cret',
                        vl_concept_id: 10_532, timeout_seconds: 15, verify_ssl: '1', active: '1' }
      }

      expect(response).to redirect_to(integration_emr_instances_path)
      created = EmrInstance.find_by(name: 'MaHIS')
      expect(created.base_url).to eq('https://mahis.health.gov.mw')
      expect(created.password).to eq('s3cret')
      expect(created.password_before_type_cast).not_to include('s3cret')
    end

    it 'keeps the saved password when the field is left blank' do
      form_submit :patch, integration_emr_instance_path(instance), { emr_instance: { name: 'MaHIS Renamed', password: '' } }

      expect(instance.reload).to have_attributes(name: 'MaHIS Renamed', password: 'secret')
    end

    it 'deletes an unused instance' do
      form_submit :delete, integration_emr_instance_path(instance)

      expect(response).to redirect_to(integration_emr_instances_path)
      expect(EmrInstance.exists?(instance.id)).to be(false)
    end

    it 'will not delete an instance that sites still use' do
      site.update!(integration_mode: 'central_emr', emr_instance: instance, mahis_location_id: 8)
      form_submit :delete, integration_emr_instance_path(instance)

      expect(EmrInstance.exists?(instance.id)).to be(true)
    end

    it 'signs out through the sign out button form' do
      form_submit :delete, integration_logout_path
      expect(response).to redirect_to(integration_login_path)
      get integration_sites_path
      expect(response).to redirect_to(integration_login_path)
    end

    it 'renders the instance and settings forms' do
      get new_integration_emr_instance_path
      expect(response).to have_http_status(:ok)
      get edit_integration_emr_instance_path(instance)
      expect(response.body).to include('Saved — leave blank to keep')
      get edit_integration_site_path(site)
      expect(response.body).to include('MaHIS Central')
      get edit_integration_settings_path
      expect(response.body).to include('HIV Viral Load')
    end

    it 'saves check settings and rejects invalid ones' do
      form_submit :patch, integration_settings_path, { settings: { vl_concept_id: '900', stale_sync_hours: '24' } }
      expect(IntegrationStatus::Settings.load).to have_attributes(vl_concept_id: 900, stale_sync_hours: 24)

      form_submit :patch, integration_settings_path, { settings: { parallel_threads: '0' } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(IntegrationStatus::Settings.load.parallel_threads).to eq(8)
    end
  end
end
