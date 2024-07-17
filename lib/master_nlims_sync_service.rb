# frozen_string_literal: true

require 'sync_util_service'

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
    return if service_type == 'account_creation'

    @token = authenticate_with_master_nlims
  end

  def process_orders(date: nil)
    pending_tests = tests_without_results(date: date)
    exit if pending_tests.empty? || @token.blank?

    pending_tests.each do |pending_test|
      tracking_number, test_name, test_id, test_type_id = pending_test.values_at(
        :tracking_number, :test_name, :test_id, :test_type_id
      )
      order = query_order_from_master_nlims(tracking_number, test_name)
      next if order['error']

      tests = order['data']['tests']
      results = order['data']['other']['results']
      process_results(tracking_number, results, test_id, test_type_id)
      tests.each do |test_type_name, details|
        update_test_status(test_type_name, test_id, details['status'], details['update_details'])
      end
    end
  end

  def push_acknwoledgement_to_master_nlims(pending_acks: nil)
    pending_acks ||= ResultsAcknwoledge.where(acknwoledged_to_nlims: false)
    return if pending_acks.empty?

    pending_acks.each do |ack|
      data = buid_acknowledment_to_master_data(ack)
      url = "#{@protocol}:#{@port}/api/v1/acknowledge/test/results/recipient"
      response = JSON.parse(RestClient.post(
                              url,
                              data.to_json,
                              content_type: 'application/json',
                              token: @token
                            ))
      next if response['error']

      ack.update(acknwoledged_to_nlims: true)
      puts "Pushed acknowledgments for tracking number: #{ack.tracking_number} to Master NLIMS"
    rescue StandardError => e
      puts "Error: #{e.message} ==> NLIMS Push Acknowledgement to Master NLIMS"
      SyncErrorLog.create(
        error_message: e.message,
        error_details: { message: 'NLIMS Push Acknowledgement to Master NLIMS' }
      )
      next
    end
  end

  private

  def buid_acknowledment_to_master_data(acknowledgement)
    test_to_ack = TestType.find(Test.find(acknowledgement.test_id).test_type_id).name
    level = TestResultRecepientType.find_by(id: acknowledgement.acknwoledment_level)
    {
      'tracking_number': acknowledgement.tracking_number,
      'test': test_to_ack,
      'date_acknowledged': acknowledgement.acknwoledged_at,
      'recipient_type': level&.name,
      'acknwoledment_by': acknowledgement.acknwoledged_by
    }
  end

  def process_results(tracking_number, results, test_id, test_type_id)
    return if results.blank?

    results.each do |key, measures|
      next unless TestType.find_by(name: key)&.id == test_type_id

      create_test_results(tracking_number, measures, test_id)
    end
  end

  def create_test_results(tracking_number, measures, test_id)
    measures.each do |measure_name, result|
      measure = Measure.find_by(name: measure_name)
      next if measure.nil? || result.blank? || result['result'].blank?

      TestResult.create(
        test_id: test_id,
        measure_id: measure.id,
        result: result['result'],
        time_entered: result['result_date']
      )
      ack_result_at_facility_level(
        tracking_number,
        test_id,
        result['result_date'],
        3,
        'local_nlims_at_facility'
      )
    end
  end

  def acknowledged_already?(tracking_number, acknowledge_by)
    ResultsAcknwoledge.find_by(
      tracking_number: tracking_number,
      acknwoledged_by: acknowledge_by
    ).nil?
  end

  def update_test_status(test_name, test_id, status, details)
    test_status = 'test-rejected' if status == 'rejected'
    test_type_id = TestType.find_by(name: test_name)&.id
    test_status_id = TestStatus.find_by(name: test_status)&.id
    return if test_status_id.blank? || test_type_id.blank?
    return if status_updated_already?(test_id, test_status_id)

    Test.find_by(id: test_id)&.update(test_status_id: test_status_id)
    return unless test_status == details['status']

    TestStatusTrail.create(
      test_id: test_id,
      time_updated: details['time_updated'],
      test_status_id: test_status_id,
      who_updated_id: details['updater_id'],
      who_updated_name: details['updater_name'],
      who_updated_phone_number: ''
    )
    puts "Status updated for #{test_id} with status #{test_status}"
  end

  # Acknowledge result at facility level
  def ack_result_at_facility_level(track_n, test_id, result_date, level, ack_by)
    return unless acknowledged_already?(track_n, ack_by)

    ResultsAcknwoledge.create(
      tracking_number: track_n,
      test_id: test_id,
      acknwoledged_at: Time.new.strftime('%Y%m%d%H%M%S'),
      result_date: result_date,
      acknwoledged_by: ack_by,
      acknwoledged_to_nlims: false,
      acknwoledment_level: level
    )
    test_record = Test.find_by(id: test_id)
    test_record.update(
      result_given: 0,
      date_result_given: Time.new.strftime('%Y%m%d%H%M%S'),
      test_result_receipent_types: level
    )
  end

  def status_updated_already?(test_id, test_status_id)
    res = Test.find_by(id: test_id, test_status_id: test_status_id)
    return false if res.nil?

    puts "Test #{test_id} has already been updated to status #{test_status_id}"
    true
  end

  def tests_without_results(date: nil)
    date ||= Date.today - 120
    tests = Test.find_by_sql("SELECT
                    specimen.tracking_number AS tracking_number,
                    specimen.id AS specimen_id,
                    tests.id AS test_id,
                    test_type_id AS test_type_id,
                    test_types.name AS test_name
                  FROM
                    tests
                    INNER JOIN specimen ON specimen.id = tests.specimen_id
                    INNER JOIN test_types ON test_types.id = tests.test_type_id
                  WHERE
                    tests.id NOT IN (SELECT test_id FROM test_results
                      WHERE test_id IS NOT NULL)
                    AND DATE(specimen.date_created) > '#{date}'
                  ")
    tests.map do |test|
      {
        tracking_number: test.tracking_number,
        test_name: test.test_name,
        test_id: test.test_id,
        specimen_id: test.specimen_id,
        test_type_id: test.test_type_id
      }
    end
  end

  def query_order_from_master_nlims(tracking_number, test_name)
    url = "#{@protocol}:#{@port}/api/v2/query_order_by_tracking_number/#{tracking_number}?test_name=#{test_name}"
    @token = authenticate_with_master_nlims
    JSON.parse(RestClient.get(
                 url,
                 content_type: 'application/json',
                 token: @token
               ))
  rescue StandardError => e
    puts "Error: #{e.message} ==> Master NLIMS Query"
    SyncErrorLog.create(
      error_message: e.message,
      error_details: {
        message: 'ERROR Master NLIMS Query',
        tracking_number: tracking_number, test_name: test_name
      }
    )
    JSON.parse({ error: true, message: e.message }.to_json)
  end

  def authenticate_with_master_nlims
    auth = RestClient.get(
      "#{@protocol}:#{@port}/api/v1/re_authenticate/#{@username}/#{@password}"
    )
    handle_response(auth)
  rescue StandardError => e
    puts "Error: #{e.message} ==> Master NLIMS Authentication"
    handle_error(e)
  end

  def load_config
    YAML.load_file("#{Rails.root}/config/master_nlims.yml")
  rescue StandardError => e
    puts "Error: #{e.message}"
    SyncErrorLog.create(
      error_message: e.message,
      error_details: { message: 'Master NLIMS Configuration missing' }
    )
    exit
  end

  def handle_response(response)
    user = JSON.parse(response)
    if user['errors']
      puts "Master NLIMS authentication failed: #{user['errors']}"
      SyncErrorLog.create(
        error_message: user['errors'],
        error_details: {
          message: "Master NLIMS Authentication @ #{@protocol}:#{@port}"
        }
      )
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
      error_details: {
        message: "Master NLIMS Authentication @ #{@protocol}:#{@port}"
      }
    )
    ''
  end
end
