# frozen_string_literal: true

# Service class for syncing order results and statuses between master nlims and local nlims
class MasterNlimsSyncService
  def initialize(service_type: nil)
    config = load_config
    @username = config['username']
    @password = config['password']
    @protocol = config['protocol']
    @port = config['port']
    @default_username = config['default_username']
    @default_password = config['default_password']
    @location = config['location']
    @token = authenticate_with_master_nlims unless service_type == 'account_creation'
  end

  private

  def query_order_from_master_nlims(tracking_number, test_name)
    url = "#{@protocol}:#{@port}/api/v2/query_order_by_tracking_number/#{tracking_number}?test_name=#{test_name}"
    JSON.parse(RestClient.get(url, { content_type: 'application/json', token: @token }))
  rescue StandardError => e
    puts "Error: #{e.message} ==> Master NLIMS Query"
    SyncErrorLog.create(
      error_message: e.message,
      error_details: { message: 'ERROR Master NLIMS Query', tracking_number: tracking_number, test_name: test_name }
    )
    { error: true, message: e.message }
  end

  def authenticate_with_master_nlims
    auth = RestClient.get("#{@protocol}:#{@port}/api/v1/re_authenticate/#{@username}/#{@password}")
    handle_response(auth)
  rescue StandardError => e
    puts "Error: #{e.message} ==> Master NLIMS Authentication"
    handle_error(e)
  end

  def load_config
    YAML.load_file("#{Rails.root}/config/master_nlims.yml")
  rescue StandardError => e
    puts "Error: #{e.message}"
    SyncErrorLog.create(error_message: e.message, error_details: { message: 'Master NLIMS Configuration missing' })
    exit
  end

  def handle_response(response)
    user = JSON.parse(response)
    if user['errors']
      puts "Master NLIMS authentication failed: #{user['errors']}"
      SyncErrorLog.create(error_message: user['errors'],
                          error_details: { message: "Master NLIMS Authentication @ #{@protocol}:#{@port}" })
      ''
    else
      puts 'Master NLIMS authentication successful'
      user['data']['token']
    end
  end

  def handle_error(error)
    puts "Error: #{error.message} ==> Master NLIMS Authentication"
    SyncErrorLog.create(
      error_message: error.message,
      error_details: { message: "Master NLIMS Authentication @ #{@protocol}:#{@port}" }
    )
    ''
  end
end
