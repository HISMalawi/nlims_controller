# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IntegrationStatusService do
  let(:mahis_url) { 'https://mahis.example.test' }
  let(:instance) do
    EmrInstance.create!(name: 'MaHIS Central', base_url: mahis_url, username: 'nlims', password: 'secret',
                        vl_concept_id: 10_532)
  end
  let!(:local_site) do
    Site.create!(name: 'Local Health Centre', district: 'Lilongwe', enabled: true,
                 host_address: '10.0.0.5', application_port: '3010')
  end
  let!(:central_site) do
    Site.create!(name: 'Area 18 Urban Health Centre', district: 'Lilongwe', enabled: true,
                 integration_mode: Site::CENTRAL_EMR, emr_instance: instance, mahis_location_id: 8)
  end
  let(:http_calls) { [] }
  let(:responses) { {} }

  before(:all) do
    ActiveRecord::Encryption.configure(primary_key: 'test-primary-key-0123456789abcdef',
                                       deterministic_key: 'test-deterministic-key-0123456789',
                                       key_derivation_salt: 'test-salt-0123456789abcdef')
  end

  before do
    Config.create!(config_type: 'integration_status', configs: { parallel_threads: 1 })
    allow(Net::Ping::External).to receive(:new).and_return(instance_double(Net::Ping::External, ping?: true))
    allow(IntegrationStatus::Http).to receive(:request_json) do |method:, url:, **options|
      http_calls << { method:, url:, **options }
      path = URI.parse(url).path
      handler = responses.find { |pattern, _| path.end_with?(pattern) }&.last
      raise Errno::ECONNREFUSED, url unless handler

      handler.respond_to?(:call) ? handler.call(url, options) : handler
    end
  end

  def local_responses
    responses['/api/v1/ping'] = { 'ping' => true, 'version' => 'v5.0.0 (Local Nlims)' }
    responses['/orders_summary'] = {
      'emr' => { 'count' => 3, 'last_order_date' => '2026-10-05', 'lab_orders' => [], 'remark' => 'Orders drawn in EMR' },
      'nlims_local' => { 'count' => 3, 'lab_orders' => [] }
    }
  end

  def central_responses(count: 2)
    responses['/api/v1/_health'] = { 'status' => 'Up' }
    responses['/api/v1/version'] = { 'System version' => 'v2.1.0' }
    responses['/api/v1/lab/users/login'] = { 'auth_token' => 'token-123' }
    responses['/api/v1/lab/orders/summary'] = { 'count' => count, 'last_order_date' => '2026-10-04', 'lab_orders' => [] }
  end

  def row_for(rows, site)
    rows.find { |row| row['name'] == site.name }
  end

  describe '#check_integration_status' do
    it 'produces rows with the same keys for both modes' do
      local_responses
      central_responses
      rows = described_class.new.check_integration_status

      expect(rows.size).to eq(2)
      expect(row_for(rows, local_site).keys).to match_array(row_for(rows, central_site).keys)
      expect(row_for(rows, local_site).keys).to include(
        'name', 'ip_address', 'app_port', 'ping_status', 'app_status', 'app_version', 'status_last_updated',
        'last_sync_date_gt_24hr', 'last_sync_date', 'order_summary', 'last_app_check_in_date',
        'integration_mode', 'emr_instance', 'ping_method', 'check_errors'
      )
    end

    it 'checks local NLIMS sites through the site server' do
      local_responses
      central_responses
      row = row_for(described_class.new.check_integration_status, local_site)

      expect(row).to include('integration_mode' => 'local_nlims', 'ping_method' => 'icmp', 'ip_address' => '10.0.0.5',
                             'app_port' => '3010', 'ping_status' => true, 'app_status' => true,
                             'app_version' => 'v5.0.0 (Local Nlims)', 'emr_instance' => nil)
      expect(row['order_summary']['emr']['count']).to eq(3)
      expect(row['order_summary']['nlims_local']['count']).to eq(3)
      summary_call = http_calls.find { |c| c[:url].end_with?('/orders_summary') }
      expect(summary_call[:url]).to eq('http://10.0.0.5:3010/orders_summary')
      expect(summary_call[:payload][:concept]).to eq({ name: 'HIV Viral Load', id: 856 })
    end

    it 'checks central EMR sites through the central EMR, filtered by location and concept' do
      local_responses
      central_responses(count: 0)
      row = row_for(described_class.new.check_integration_status, central_site)

      expect(row).to include('integration_mode' => 'central_emr', 'ping_method' => 'http_health',
                             'ip_address' => 'mahis.example.test', 'app_port' => '443', 'emr_instance' => 'MaHIS Central',
                             'ping_status' => true, 'app_status' => true, 'app_version' => 'v2.1.0',
                             'last_app_check_in_date' => nil, 'check_errors' => [])
      expect(row['order_summary']['nlims_local']).to include('applicable' => false)
      expect(row['order_summary']['overall_remark']).to eq('No orders drawn in EMR and no orders synched to NLIMS')

      summary_call = http_calls.find { |c| c[:url].include?('/lab/orders/summary') }
      query = Rack::Utils.parse_query(URI.parse(summary_call[:url]).query)
      expect(query).to include('location_id' => '8', 'concept_id' => '10532')
      expect(summary_call[:headers]).to eq(Authorization: 'Bearer token-123')
      expect(Net::Ping::External).not_to have_received(:new).with('mahis.example.test', anything, anything)
    end

    it 'calls health, version and login once per central instance however many sites use it' do
      Site.create!(name: 'Second Central Site', district: 'Lilongwe', enabled: true,
                   integration_mode: Site::CENTRAL_EMR, emr_instance: instance, mahis_location_id: 9)
      local_responses
      central_responses
      described_class.new.check_integration_status

      count = ->(path) { http_calls.count { |c| URI.parse(c[:url]).path == path } }
      expect(count.call('/api/v1/_health')).to eq(1)
      expect(count.call('/api/v1/version')).to eq(1)
      expect(count.call('/api/v1/lab/users/login')).to eq(1)
      expect(count.call('/api/v1/lab/orders/summary')).to eq(2)
    end

    it 'reports a failed login once and on every central site' do
      Site.create!(name: 'Second Central Site', district: 'Lilongwe', enabled: true,
                   integration_mode: Site::CENTRAL_EMR, emr_instance: instance, mahis_location_id: 9)
      local_responses
      central_responses
      responses['/api/v1/lab/users/login'] = ->(*) { raise RestClient::Unauthorized }
      rows = described_class.new.check_integration_status

      central_rows = rows.select { |r| r['integration_mode'] == 'central_emr' }
      expect(central_rows.map { |r| r['order_summary']['overall_remark'] })
        .to all(eq('MaHIS Authentication Failed - invalid credentials'))
      expect(http_calls.count { |c| c[:url].end_with?('/login') }).to eq(1)
      expect(central_rows.first['app_status']).to be(true)
    end

    it 'explains a lab login that crashes because the account is not a lab API user' do
      central_responses
      responses['/api/v1/lab/users/login'] = ->(*) { raise RestClient::InternalServerError.new(nil, 500) }
      result = IntegrationStatus::EmrInstanceClient.new(instance).test_connection

      expect(result[:authenticated]).to be(false)
      expect(result[:auth_error]).to include("'nlims' is a lab API user", 'POST https://mahis.example.test/api/v1/lab/users')
    end

    it 'marks the central EMR unreachable without asking it for orders' do
      local_responses
      responses['/api/v1/_health'] = ->(*) { raise RestClient::Exceptions::OpenTimeout }
      row = row_for(described_class.new.check_integration_status, central_site)

      expect(row).to include('ping_status' => false, 'app_status' => false)
      expect(row['order_summary']['overall_remark']).to eq('MaHIS Not Reachable')
      expect(http_calls.none? { |c| c[:url].include?('/lab/orders/summary') }).to be(true)
    end

    it 'treats an unhealthy but answering central EMR as reachable and down' do
      local_responses
      central_responses
      responses['/api/v1/_health'] = { 'status' => 'Down', 'error' => 'Database unreachable' }
      row = row_for(described_class.new.check_integration_status, central_site)

      expect(row).to include('ping_status' => true, 'app_status' => false)
      expect(row['check_errors']).to include('Health: Database unreachable')
    end

    it 'reports central sites on a disabled instance instead of checking them' do
      instance.update!(active: false)
      local_responses
      row = row_for(described_class.new.check_integration_status, central_site)

      expect(row['order_summary']['overall_remark']).to eq("Central EMR instance 'MaHIS Central' is disabled")
      expect(http_calls.none? { |c| c[:url].start_with?(mahis_url) }).to be(true)
    end

    it 'keeps local sites in the report when their NLIMS is unreachable or errors' do
      central_responses
      responses['/api/v1/ping'] = ->(*) { raise RestClient::InternalServerError }
      row = row_for(described_class.new.check_integration_status, local_site)

      expect(row).to include('app_status' => false, 'app_version' => 'N/A')
      expect(row['order_summary']['overall_remark']).to eq('NLIMS Local Not Reachable')
      expect(row['check_errors'].first).to start_with('Order summary:')
    end

    it 'falls back to re_authenticate for NLIMS versions without /ping' do
      central_responses
      responses['/api/v1/ping'] = ->(*) { raise RestClient::NotFound }
      responses['/re_authenticate/aexede/aexede'] = { 'error' => true, 'message' => 'wrong credentials' }
      row = row_for(described_class.new.check_integration_status, local_site)

      expect(row['app_status']).to be(true)
    end

    it 'gives the same results when sites are checked in parallel' do
      Config.find_by(config_type: 'integration_status').update!(configs: { parallel_threads: 4 })
      local_responses
      central_responses
      rows = described_class.new.check_integration_status

      expect(rows.map { |r| r['name'] }).to contain_exactly(local_site.name, central_site.name)
      expect(rows.map { |r| r['app_status'] }).to all(be(true))
    end
  end

  describe '#refresh_site' do
    it 'replaces only that site in the stored report' do
      Report.create!(name: 'integration_status', data: [{ 'name' => 'Other Site', 'app_status' => true },
                                                         { 'name' => central_site.name, 'app_status' => false }])
      central_responses
      row = described_class.new.refresh_site(central_site)

      data = Report.find_by(name: 'integration_status').data
      expect(data.map { |r| r['name'] }).to eq([central_site.name, 'Other Site'])
      expect(data.first).to eq(row.as_json)
      expect(row['app_status']).to be(true)
    end
  end

  describe '#check_site' do
    it 'checks unsaved changes without persisting them' do
      central_responses
      local_site.assign_attributes(integration_mode: Site::CENTRAL_EMR, emr_instance_id: instance.id, mahis_location_id: 77)
      row = described_class.new.check_site(local_site)

      expect(row['integration_mode']).to eq('central_emr')
      expect(local_site.reload.integration_mode).to eq('local_nlims')
    end
  end

  describe '#generate_status_report' do
    it 'stores the current report and a history entry' do
      local_responses
      central_responses
      described_class.new.generate_status_report

      expect(Report.find_by(name: 'integration_status').data.size).to eq(2)
      expect(Report.where(name: 'integration_status_history').count).to eq(1)
    end
  end
end
