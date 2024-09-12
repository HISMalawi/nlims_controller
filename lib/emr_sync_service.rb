# frozen_string_literal: true

require 'order_service'
# EMRSyncService for syncing status of orders to EMR and results
class EmrSyncService
  def initialize(service_type: nil, app: 'emr')
    config = app == 'emr' ? load_config['emr'] : load_config['mahis']
    @username = config['username']
    @password = config['password']
    @protocol = config['protocol']
    @port = config['port']
    @active = config['active']
    @token = authenticate_with_emr unless service_type == 'account_creation'
  end

  def active_connection?
    @active
  end

  def mahis?(tracking_number)
    tracking_number.downcase.include?('test')
  end

  def push_status_to_emr(tracking_number, status, status_time)
    url = "#{@protocol}:#{@port}/api/v1/lab/orders/order_status"
    payload = {
      tracking_number: tracking_number,
      status: status,
      status_time: status_time
    }
    post_to_emr(url, payload)
  end

  def push_result_to_emr(tracking_number)
    url = "#{@protocol}:#{@port}/api/v1/lab/orders/order_result"
    payload = buid_results_payload(tracking_number)
    return unless payload[:data][:results]

    post_to_emr(url, payload)
  end

  def create_account_in_emr
    url = "#{@protocol}:#{@port}/api/v1/lab/users"
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
    url = "#{@protocol}:#{@port}/api/v1/lab/users/login"
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
        tracking_number: tracking_number,
        results: results
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
    SyncErrorLog.create(error_message: e.message, error_details: payload)
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

  def load_config
    YAML.load_file("#{Rails.root}/config/emr_connection.yml")
  rescue StandardError => e
    puts "Error: #{e.message}"
    SyncErrorLog.create(error_message: e.message, error_details: { message: 'EMR Configuration missing' })
    exit
  end
end
