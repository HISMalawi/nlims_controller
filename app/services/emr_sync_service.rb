# frozen_string_literal: true

require 'order_service'
# EMRSyncService for syncing status of orders to EMR and results
class EmrSyncService
  def initialize(tracking_number, service_type: nil)
    config = emr_configs(tracking_number)
    @username = config['username']
    @password = config['password']
    @address = "#{config['address']}:#{config['port']}"
    @token = authenticate_with_emr unless service_type == 'account_creation'
  end

  def push_status_to_emr(tracking_number, status, status_time, test_id)
    url = "#{@address}/api/v1/lab/orders/order_status"
    payload = {
      tracking_number:,
      status:,
      status_time:
    }
    response = post_to_emr(url, payload)
    return unless response

    StatusSyncTracker.find_by(tracking_number:, test_id:, status:, app: 'emr')&.update(sync_status: true)
  end

  def push_result_to_emr(tracking_number, test_id, time_entered)
    url = "#{@address}/api/v1/lab/orders/order_result"
    payload = buid_results_payload(tracking_number)
    return unless payload[:data][:results]

    response = post_to_emr(url, payload)
    return unless response

    SyncUtilService.ack_result_at_facility_level(
      tracking_number,
      test_id,
      time_entered,
      2,
      'emr_at_facility'
    )
    ResultSyncTracker.find_by(tracking_number:, test_id:, app: 'emr')&.update(sync_status: true)
  end

  def create_account_in_emr
    url = "#{@address}/api/v1/lab/users"
    JSON.parse(RestClient.post(
                 url,
                 { 'username': @username, 'password': @password }.to_json,
                 content_type: 'application/json'
               ))
    puts 'Account created in EMR'
  rescue StandardError => e
    puts "Error creating account in EMR: #{e.message}"
    SyncErrorLog.create(error_message: e.message, error_details: { message: 'ERROR Account creation in EMR' })
  end

  private

  # Authenticate with EMR
  def authenticate_with_emr
    url = "#{@address}/api/v1/lab/users/login"
    response = RestClient.post(
      url,
      { 'username': @username, 'password': @password },
      content_type: 'application/json'
    )
    handle_response(response)
  rescue StandardError => e
    handle_error(e)
  end

  def buid_results_payload(tracking_number)
    results = OrderService.query_results_by_tracking_number(tracking_number)
    {
      data: {
        tracking_number:,
        results:
      }
    }
  end

  # Push the payload to EMR
  def post_to_emr(url, payload)
    response = RestClient.post(
      url,
      payload.to_json,
      content_type: 'application/json',
      Authorization: "Bearer #{@token}"
    )
    res = JSON.parse(response)
    !res['message'].blank?
  rescue StandardError => e
    puts "Error: #{e.message}"
    SyncUtilService.log_error(
      error_message: e.message,
      custom_message: "Push to EMR @ #{@address}",
      payload:
    )
    false
  end

  def handle_response(response)
    res = JSON.parse(response)
    if res['errors'].blank?
      puts 'EMR authentication successful'
      res['auth_token']
    else
      puts "EMR authentication failed: #{res['errors']}"
      SyncErrorLog.create(error_message: res['errors'], error_details: { message: 'EMR Authentication' })
      ''
    end
  end

  def handle_error(error)
    puts "Error: #{error.message} ==> EMR Authentication"
    SyncErrorLog.create(error_message: error.message, error_details: { message: 'EMR Authentication' })
    ''
  end

  def emr_configs(tracking_number)
    host = TrackingNumberHost.find_by(tracking_number:)
    address = host&.source_host
    address ||= host&.update_host
    app = application(host)
    config = load_config(app)
    config['address'] = address if address
    config
  end

  def application(host)
    app_uuid = host&.source_app_uuid
    app_uuid ||= host&.update_app_uuid
    User.find_by(app_uuid:)&.app_name
  end

  def load_config(app)
    config = if app == 'MAHIS'
               Config.configurations('mahis')
             else
               Config.configurations('emr')
             end
    settings = YAML.load_file("#{Rails.root}/config/settings.yml")
    config['password'] = app == 'MAHIS' ? settings['mahis'] : settings['emr']
    config
  end
end
