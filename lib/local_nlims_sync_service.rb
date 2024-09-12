# frozen_string_literal: true

class LocalNlimsSyncService
  MASTER_IP = '10.44.0.46'
  def initialize(tracking_number)
    @host = local_nlims_host(tracking_number)
    config = load_config
    @username = config['username']
    @password = config['password']
    @port = config['port']
    @protocol = config['protocol']
    @address = "#{@protocol}://#{@host}:#{@port}"
    @token = authenticate_with_local_nlims
  end

  def order_status_payload(order_id)
    order = Speciman.find_by(id: order_id)
    order_status_trail = SpecimenStatusTrail.where(specimen_id: order&.id).order(created_at: :desc).first
    {
      tracking_number: order&.tracking_number,
      status: SpecimenStatus.find_by(id: order_status_trail&.specimen_status_id)&.name,
      who_updated: who_updated(order_status_trail)
    }
  end

  def push_order_update_to_nlims(order_id)
    payload = order_status_payload(order_id)
    url = "#{@address}/api/v1/update_order"
    response = RestClient.post(url, payload.to_json, content_type: :json, token: @token)
    if response['error'] == false && response['message'] == 'order updated successfuly'
      puts 'Order actions pushed to Local NLIMS successfully'
      OrderStatusSyncTracker.find_by(
        tracking_number: payload[:tracking_number],
        status: payload[:status]
      )&.update(sync_status: true)
      return true
    end
    false
  rescue StandardError => e
    puts "Error: #{e.message} ==> Local NLIMS Order Push"
    SyncErrorLog.create(
      error_message: response['errors'],
      error_details: {
        message: "Failed to push order actions to Local NLIMS @ #{@address}",
        payload: payload
      }
    )
    false
  end

  def push_test_actions_to_nlims(test_id: nil, action: 'status_update')
    test_record = Test.find_by(id: test_id)
    tracking_number = Speciman.find(test_record&.specimen_id)&.tracking_number
    payload = test_action_payload(tracking_number, test_record, action)
    url = "#{@address}/api/v1/update_test"
    response = RestClient.post(url, payload.to_json, content_type: :json, token: @token)
    if response['error'] == false && response['message'] == 'test updated successfuly'
      puts 'Test actions pushed to Local NLIMS successfully'
      unless action == 'status_update'
        ResultSyncTracker.find_by(tracking_number: tracking_number, test_id: test_id, app: 'nlims')&.update(sync_status: true)
      end
      StatusSyncTracker.find_by(
        tracking_number: tracking_number,
        test_id: test_id,
        status: payload[:test_status],
        app: 'nlims'
      )&.update(sync_status: true)
      return true
    end
    false
  rescue StandardError => e
    puts "Error: #{e.message} ==> Local NLIMS test actions Push"
    SyncErrorLog.create(
      error_message: e,
      error_details: {
        message: "Failed to push test actions to Local NLIMS @ #{@address}",
        payload: payload
      }
    )
    false
  end

  def test_action_payload(tracking_number, test_record, action)
    results_object = {}
    results = []
    unless action == 'status_update'
      results = TestResult.where(test_id: test_record&.id)
    end
    results.each do |result|
      next if result.result.blank? || result.measure_id.blank?

      results_object[Measure.find_by(id: result.measure_id)&.name] = result&.result
    end
    test_status_trail = TestStatusTrail.where(test_id: test_record&.id).order(created_at: :desc).first
    payload = {
      tracking_number: tracking_number,
      test_status: TestStatus.find_by(id: test_status_trail&.test_status_id)&.name,
      test_name: TestType.find_by(id: test_record&.test_type_id)&.name,
      result_date: '',
      who_updated: who_updated(test_status_trail)
    }
    return payload if results.empty?

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
    if who_updated_name.length == 1
      return { first_name: who_updated_name[0], last_name: who_updated_name[0], id: '' }
    end

    {
      first_name: who_updated_name[0],
      last_name: who_updated_name[1],
      id: ''
    }
  end

  def authenticate_with_local_nlims
    auth = RestClient.get(
      "#{@address}/api/v1/re_authenticate/#{@username}/#{@password}"
    )
    handle_response(auth)
  rescue StandardError => e
    puts "Error: #{e.message} ==> Local NLIMS Authentication"
    handle_error(e)
  end

  def handle_response(response)
    user = JSON.parse(response)
    if user['error']
      puts "Local NLIMS authentication failed: #{user['message']}"
      SyncErrorLog.create(
        error_message: user['message'],
        error_details: {
          message: "Local NLIMS Authentication @ #{@address}"
        }
      )
      ''
    else
      puts 'Local NLIMS authentication successful'
      user['data']['token']
    end
  end

  def handle_error(error)
    puts "Error: #{error.message} ==> Local NLIMS Authentication"
    SyncErrorLog.create(
      error_message: error.message,
      error_details: {
        message: "Local NLIMS Authentication @ #{@address}"
      }
    )
    ''
  end

  def local_nlims_host(track_number)
    return MASTER_IP if track_number.nil?

    host = TrackingNumberHost.find_by(tracking_number: track_number)
    address = host&.source_host
    address ||= host&.update_host
    address
  end

  def load_config
    config = if @host == MASTER_IP
               YAML.load_file("#{Rails.root}/config/master_nlims.yml")
             else
               YAML.load_file("#{Rails.root}/config/local_nlims.yml")
             end
    config['protocol'] = 'http' if @host == MASTER_IP
    config
  rescue StandardError => e
    puts "Error: #{e.message}"
    SyncErrorLog.create(
      error_message: e.message,
      error_details: { message: 'Local NLIMS Configuration missing' }
    )
    exit
  end
end
