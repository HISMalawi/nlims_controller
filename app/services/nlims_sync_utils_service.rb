# frozen_string_literal: true

class NlimsSyncUtilsService
  attr_reader :address, :token

  def initialize(tracking_number, action_type: nil)
    config = nlims_configs(tracking_number)
    @username = config['username']
    @password = config['password']['main']
    @default_password = config['password']['default']
    @address = "#{config['address']}:#{config['port']}"
    @token = token_valid(@username) || authenticate_with_nlims if action_type.nil?
    @token = default_authentication if action_type == 'account_creation'
  end

  def order_status_payload(order_id, status)
    order = Speciman.find_by(id: order_id)
    if status.nil?
      status = OrderStatusSyncTracker.find_by(tracking_number: order&.tracking_number, sync_status: false)&.status
    end
    specimen_status_id = SpecimenStatus.find_by(name: status)&.id
    order_status_trail = SpecimenStatusTrail.find_by(specimen_id: order&.id, specimen_status_id:)
    return nil if order_status_trail.nil?

    {
      tracking_number: order&.tracking_number,
      status: status,
      who_updated: who_updated(order_status_trail)
    }
  end

  def push_order_update_to_nlims(order_id, status: nil)
    payload = order_status_payload(order_id, status)
    return true if payload.nil?

    url = "#{@address}/api/v1/update_order"
    response = JSON.parse(RestClient::Request.execute(
                            method: :post,
                            url:,
                            timeout: 10,
                            payload:,
                            content_type: :json,
                            headers: { content_type: :json, accept: :json, token: @token }
                          ))
    if response['error'] == false && response['message'] == 'order updated successfuly'
      puts 'Order actions pushed to Local NLIMS successfully'
      OrderStatusSyncTracker.find_by(
        tracking_number: payload[:tracking_number],
        status: payload[:status]
      )&.update(sync_status: true)
      return true
    end
    if response['error'] == false && response['message'] == 'order not available'
      OrderStatusSyncTracker.find_by(
        tracking_number: payload[:tracking_number],
        status: payload[:status]
      )&.update(sync_status: true)
      return true
    end
    SyncUtilService.log_error(
      error_message: response['message'],
      custom_message: "Failed to push order actions to Local NLIMS @ #{@address}",
      payload:
    )
    false
  rescue StandardError => e
    puts "Error: #{e.message} ==> Local NLIMS Order Push"
    SyncUtilService.log_error(
      error_message: e.message,
      custom_message: "Failed to push order actions to Local NLIMS @ #{@address}",
      payload:
    )
    false
  end

  def push_test_actions_to_nlims(test_id: nil, action: 'status_update')
    test_record = Test.find_by(id: test_id)
    tracking_number = Speciman.find(test_record&.specimen_id)&.tracking_number
    payload = test_action_payload(tracking_number, test_record, action)
    return true if payload.nil?

    url = "#{@address}/api/v1/update_test"
    response = JSON.parse(RestClient::Request.execute(
                            method: :post,
                            url:,
                            timeout: 10,
                            payload:,
                            content_type: :json,
                            headers: { content_type: :json, accept: :json, token: @token }
                          ))
    unless (response['error'] == false && response['message'] == 'test updated successfuly') || (response['error'] == true && response['message'] == 'order already updated with such state')
      return false
    end

    unless action == 'status_update'
      ResultSyncTracker.find_by(tracking_number:, test_id:, app: 'nlims')&.update(sync_status: true)
    end
    StatusSyncTracker.find_by(
      tracking_number:,
      test_id:,
      status: payload[:test_status],
      app: 'nlims'
    )&.update(sync_status: true)
    true
  rescue StandardError => e
    puts "Error: #{e.message} ==> NLIMS test actions Push"
    SyncUtilService.log_error(
      error_message: e.message,
      custom_message: "Failed to push test actions to NLIMS @ #{@address}",
      payload:
    )
    false
  end

  def test_action_payload(tracking_number, test_record, action)
    results_object = {}
    results = []
    results = TestResult.where(test_id: test_record&.id) unless action == 'status_update'
    results.each do |result|
      next if result.result.blank? || result.measure_id.blank?

      results_object[Measure.find_by(id: result.measure_id)&.name] = result&.result
    end
    test_status = StatusSyncTracker.find_by(tracking_number:, test_id: test_record&.id, sync_status: false)&.status
    test_status ||= StatusSyncTracker.where(tracking_number:, test_id: test_record&.id).last&.status
    test_status_id = TestStatus.find_by(name: test_status)&.id
    test_status_trail = TestStatusTrail.where(test_id: test_record&.id, test_status_id:).order(created_at: :desc).first

    payload = {
      tracking_number:,
      test_status: test_status,
      test_name: TestType.find_by(id: test_record&.test_type_id)&.name,
      result_date: '',
      who_updated: who_updated(test_status_trail)
    }
    return payload if results.empty?

    payload[:test_status] = 'verified' unless test_status.present?
    payload[:result_date] = results.first&.time_entered
    payload[:platform] = results.first&.device_name
    payload[:results] = results_object
    payload
  end

  def who_updated(test_status_trail)
    return { first_name: '', last_name: '', id: '' } if test_status_trail.blank?

    who_updated_name = test_status_trail&.who_updated_name
    return { first_name: '', last_name: '', id: '' } if who_updated_name.blank?

    who_updated_name = who_updated_name.split(' ')
    return { first_name: who_updated_name[0], last_name: who_updated_name[0], id: '' } if who_updated_name.length == 1

    {
      first_name: who_updated_name[0],
      last_name: who_updated_name[1],
      id: ''
    }
  end

  def build_order_payload(tracking_number)
    order = Speciman.find_by(tracking_number:)
    return nil if order.nil? || order.specimen_type_id.zero?

    tests = Test.where(specimen_id: order&.id)
    client = Patient.find_by(id: tests&.first&.patient_id)
    who_order_test_last_name = tests&.first&.created_by&.split(' ')&.last
    who_order_test_first_name = tests&.first&.created_by&.split(' ')&.first
    {
      tracking_number: order.tracking_number,
      date_sample_drawn: order.date_created,
      date_received: order.created_at,
      health_facility_name: order.sending_facility,
      district: order.district,
      target_lab: order.target_lab,
      couch_id: order.couch_id,
      requesting_clinician: order.requested_by,
      return_json: 'true',
      sample_type: SpecimenType.find_by(id: order.specimen_type_id)&.name,
      tests: TestType.where(id: tests.pluck(:test_type_id)).pluck(:name),
      sample_status: SpecimenStatus.find_by(id: order.specimen_status_id)&.name,
      sample_priority: order.priority,
      reason_for_test: order.priority,
      order_location: Ward.find_by(id: order.ward_id)&.name || order.sending_facility,
      who_order_test_id: nil,
      who_order_test_last_name: who_order_test_last_name.blank? ? '' : who_order_test_last_name,
      who_order_test_first_name: who_order_test_first_name.blank? ? '' : who_order_test_first_name,
      who_order_test_phone_number: '',
      first_name: client.first_name,
      last_name: client.last_name,
      middle_name: client.middle_name,
      date_of_birth: client[:dob],
      gender: client.sex,
      patient_residence: client[:address],
      patient_location: '',
      patient_town: '',
      patient_district: '',
      national_patient_id: client[:patient_number],
      phone_number: client[:phone_number],
      art_start_date: order.art_start_date,
      art_regimen: order.art_regimen,
      arv_number: order.arv_number
    }
  end

  def push_order_to_master_nlims(tracking_number)
    payload = build_order_payload(tracking_number)
    return false if payload.nil?

    url = "#{@address}/api/v1/create_order/"
    response = JSON.parse(RestClient::Request.execute(
                            method: :post,
                            url:,
                            timeout: 10,
                            payload:,
                            content_type: :json,
                            headers: { content_type: :json, accept: :json, token: @token }
                          ))
    if response['error'] == false && ['order created successfuly',
                                      'order already available'].include?(response['message'])
      OrderSyncTracker.find_by(tracking_number:).update(synced: true)
      return true
    end
    SyncUtilService.log_error(
      error_message: response['message'],
      custom_message: "NLIMS Push Order to Master NLIMS @ #{@address}",
      payload:
    )
    false
  rescue StandardError => e
    puts "Error: #{e.message} ==> NLIMS Push Order to Master NLIMS"
    SyncUtilService.log_error(
      error_message: e.message,
      custom_message: "NLIMS Push Order to Master NLIMS @ #{@address}",
      payload:
    )
    false
  end

  def push_acknwoledgement_to_master_nlims(pending_acks: nil)
    pending_acks ||= ResultsAcknwoledge.where(acknwoledged_to_nlims: false)
    return if pending_acks.empty?

    pending_acks.each do |ack|
      payload = buid_acknowledment_to_master_data(ack)
      url = "#{@address}/api/v1/acknowledge/test/results/recipient"
      response = JSON.parse(RestClient::Request.execute(
                              method: :post,
                              url:,
                              timeout: 10,
                              payload:,
                              content_type: :json,
                              headers: { content_type: :json, accept: :json, token: @token }
                            ))
      if response['error']
        SyncUtilService.log_error(
          error_message: response['message'],
          custom_message: "NLIMS Push Acknowledgement to Master NLIMS @ #{@address}",
          payload:
        )
      end

      ack.update(acknwoledged_to_nlims: true)
      puts "Pushed acknowledgments for tracking number: #{ack.tracking_number} to Master NLIMS"
    rescue StandardError => e
      puts "Error: #{e.message} ==> NLIMS Push Acknowledgement to Master NLIMS"
      SyncUtilService.log_error(
        error_message: e.message,
        custom_message: "NLIMS Push Acknowledgement to Master NLIMS @ #{@address}",
        payload:
      )
      next
    end
  end

  def buid_acknowledment_to_master_data(acknowledgement)
    test_to_ack = TestType.find(Test.find(acknowledgement&.test_id)&.test_type_id)&.name
    level = TestResultRecepientType.find_by(id: acknowledgement&.acknwoledment_level)
    level ||= TestResultRecepientType.find_by(id: acknowledgement&.acknowledgment_level)
    {
      'tracking_number': acknowledgement&.tracking_number,
      'test': test_to_ack,
      'date_acknowledged': acknowledgement&.acknwoledged_at,
      'recipient_type': level&.name,
      'acknwoledment_by': acknowledgement&.acknwoledged_by
    }
  end

  def register_order_source(tracking_number)
    url = "#{@address}/api/v1/register_order_source"
    JSON.parse(RestClient::Request.execute(
                 method: :post,
                 url:,
                 timeout: 10,
                 payload: { tracking_number: },
                 content_type: :json,
                 headers: { content_type: :json, accept: :json, token: @token }
               ))
    TrackingNumberHost.find_or_create_by(
      tracking_number:,
      source_host: Config.find_by(config_type: 'emr').configs['address'] || '127.0.0.1',
      source_app_uuid: User.find_by(app_name: 'EMR')&.app_uuid || User.last&.app_uuid
    )
    OrderSyncTracker.create(tracking_number: tracking_number)
    SyncWithNlimsJob.perform_async({
      identifier: tracking_number,
      type: 'order',
      action: 'order_create'
    }.stringify_keys)
  rescue StandardError => e
    puts "Error: #{e.message} ==> NLIMS Register Source to Master NLIMS"
  end

  def authenticate_with_nlims
    auth = RestClient::Request.execute(
      method: :get,
      url: "#{@address}/api/v1/re_authenticate/#{@username}/#{@password}",
      timeout: 5
    )
    handle_response(auth)
  rescue StandardError => e
    puts "Error: #{e.message} ==> NLIMS Authentication"
    handle_error(e)
  end

  def application_status
    url = "#{@address}/api/v1/ping"
    response = RestClient.get(
      url,
      content_type: 'application/json'
    )
    res = JSON.parse(response)
    res['ping']
  rescue StandardError => e
    puts "Error: #{e.message}"
    false
  end

  def default_authentication
    url = "#{@address}/api/v1/authenticate/admin/#{@default_password}"
    response = RestClient.get(
      url,
      content_type: 'application/json'
    )
    res = JSON.parse(response)
    res['status'] == 200 ? res['data']['token'] : ''
  rescue StandardError => e
    puts "Error: #{e.message} ==> NLIMS Authentication"
  end

  def create_account
    payload = {
      username: @username,
      password: @password,
      partner: 'EGPAF',
      app_name: 'Local NLIMS',
      location: 'Malawi',
      app_uuid: User.find_by(username: @username)&.app_uuid
    }
    response = JSON.parse(RestClient::Request.execute(
                            method: :post,
                            url: "#{@address}/api/v1/create_user",
                            timeout: 10,
                            payload:,
                            content_type: :json,
                            headers: { content_type: :json, accept: :json, token: @token }
                          ))
    puts response
  rescue StandardError => e
    puts "Error: #{e.message} ==> Failed to create user at master"
  end

  def handle_response(response)
    user = JSON.parse(response)
    if user['error']
      puts "NLIMS authentication failed: #{user['message']}"
      SyncErrorLog.create(
        error_message: user['message'],
        error_details: {
          message: "NLIMS Authentication @ #{@address}"
        }
      )
      ''
    else
      puts 'NLIMS authentication successful'
      TokenTracker.find_or_create_by(username: @username)&.update(token: user['data']['token'])
      user['data']['token']
    end
  end

  def handle_error(error)
    puts "Error: #{error.message} ==> NLIMS Authentication"
    SyncErrorLog.create(
      error_message: error.message,
      error_details: {
        message: "NLIMS Authentication @ #{@address}"
      }
    )
    ''
  end

  def nlims_configs(tracking_number)
    configs = load_config
    return configs if Config.local_nlims? || tracking_number.nil?

    host = TrackingNumberHost.find_by(tracking_number:)
    address = host&.source_host
    address ||= host&.update_host
    configs['address'] = "http://#{address}"
    configs
  end

  def load_config
    settings = YAML.load_file("#{Rails.root}/config/settings.yml")
    config = if Config.local_nlims?
               Config.configurations('master_nlims')
             else
               Config.configurations('local_nlims')
             end
    config['password'] = Config.local_nlims? ? settings['local_nlims'] : settings['master_nlims']
    config
  rescue StandardError => e
    puts "Error: #{e.message}"
    SyncErrorLog.create(
      error_message: e.message,
      error_details: { message: 'NLIMS Configuration missing' }
    )
    exit
  end

  def order_tracking_numbers(order_id, limit: 200_000)
    JSON.parse(RestClient::Request.execute(
                 method: :get,
                 url: "#{@address}/api/v1/get_order_tracking_numbers?order_id=#{order_id}&limit=#{limit}",
                 headers: { content_type: :json, accept: :json, token: @token }
               ), symbolize_names: true)
  rescue StandardError => e
    puts "Error: #{e.message} ==> Failed to get order tracking numbers to be logged"
    []
  end

  def token_valid(username)
    token = TokenTracker.find_by_username(username)&.token
    return nil if token.nil?

    response = JSON.parse(RestClient::Request.execute(
                            method: :get,
                            url: "#{@address}/api/v1/check_token_validity",
                            timeout: 10,
                            headers: { content_type: :json, accept: :json, token: }
                          ))
    response['error'] == false && response['message'] == 'token active' ? token : nil
  rescue StandardError => e
    puts "Error: #{e.message} ==> NLIMS Token Validity"
    nil
  end
end
