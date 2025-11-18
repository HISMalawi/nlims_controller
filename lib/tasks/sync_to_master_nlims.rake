namespace :master_nlims do
  desc 'TODO'
  task sync_data: :environment do
    # Use NlimsSyncUtilsService to get NLIMS credentials and authentication
    exit unless Config.local_nlims?

    res = TestService.vl_without_results
    pull_and_process_data_master_nlims(res)
    push_acknwoledgement_to_master_nlims
  end
  task test_syncing: :environment do
    # Use services to get authentication status
    nlims_service = NlimsSyncUtilsService.new(nil)
    emr_service = EmrSyncService.new(nil)
    res = TestService.vl_without_results
    status = {
      local_nlims_data_available_for_syncing: res.present? ? 'Yes' : 'No',
      nlims_authenticate_with_emr: emr_service.token.present? ? 'Success' : 'Failed',
      nlims_authenticate_with_nlims_chsu: nlims_service.token.present? ? 'Success' : 'Failed'
    }
    puts status
  end

  task sync_local_nlims_acknowledge_results: :environment do
    # Use NlimsSyncUtilsService to get NLIMS credentials and authentication
    exit unless Config.local_nlims?

    last_date = (Date.today - 6.months).to_s
    receipient_type_id = TestResultRecepientType.find_by(name: 'test_results_delivered_to_site_electronically_at_local_nlims_level')&.id
    res = Test.find_by_sql("SELECT specimen.tracking_number as tracking_number, specimen.id as specimen_id,
                  tests.id as test_id,test_type_id as test_type_id, test_types.name as test_name, specimen.couch_id as couch_id
                  FROM tests INNER JOIN specimen ON specimen.id = tests.specimen_id
                  INNER JOIN test_types ON test_types.id = tests.test_type_id
                  WHERE tests.test_result_receipent_types = #{receipient_type_id}
                  AND DATE(specimen.date_created) > '#{last_date}' AND test_types.name LIKE '%Viral Load%'")
    pull_and_process_data_master_nlims(res)
    push_acknwoledgement_to_master_nlims
  end
end

def pull_and_process_data_master_nlims(res)
  nlims_service = NlimsSyncUtilsService.new(nil)
  puts "NLIMS authentication: #{nlims_service.token.present? ? 'Success' : 'Failed'}"
  return unless nlims_service.token.present?

  puts "Number of records to process for status and results syncing: #{res.count}"
  return if res.blank?

  emr_service = EmrSyncService.new(nil)
  emr_auth_status = [emr_service.token.present?, emr_service.token]
  puts "EMR authentication: #{emr_auth_status[0].present? ? 'Success' : 'Failed'}"
  return unless emr_auth_status[0].present?

  token = nlims_service.token
  headers = {
    content_type: 'application/json',
    token: token
  }
  res.each do |sample|
    tracking_number = sample[:tracking_number]
    test_id = sample[:test_id]
    couch_id = sample[:couch_id]
    begin
      url = "#{nlims_service.address}/api/v2/orders/#{tracking_number}?couch_id=#{couch_id}"
      order = JSON.parse(RestClient.get(url, headers))
      next unless order['error'] == false

      tests = order.deep_symbolize_keys[:data][:tests]
      tests.each do |lab_test|
        puts "Updating test for tracking number:  #{tracking_number}"
        status, response = OrderService.update_tests(lab_test)
        next unless status == true

        puts "Test updated for tracking number:  #{tracking_number}  --- Response: #{response}"
        next if Speciman.find_by(tracking_number:)&.source_system&.downcase == 'iblis'

        puts "Updating EMR for tracking number: #{tracking_number}"
        StatusSyncTracker.where(tracking_number:, test_id:, app: 'emr').each do |status_tracker|
          emr_service.push_status_to_emr(tracking_number, status_tracker.status, status_tracker.created_at, test_id)
        end
        test_result = TestResult.find_by(test_id:)
        emr_service.push_result_to_emr(tracking_number, test_id, test_result&.time_entered) if test_result.present?
        puts "EMR updated for tracking number: #{tracking_number}"
      end
    rescue StandardError => e
      puts "Error: #{e}"
      next
    end
  end
end

def push_acknwoledgement_to_master_nlims
  nlims_service = NlimsSyncUtilsService.new(nil)
  return unless nlims_service.token.present?

  results_acks = ResultsAcknwoledge.where(acknwoledged_to_nlims: false)
  return if results_acks.empty?

  puts "Number of acknowledgements to process: #{results_acks.count}"
  results_acks.each do |results_ack|
    puts "Acknowledgement for tracking number: #{results_ack&.tracking_number}"
    data = nlims_service.buid_acknowledment_to_master_data(results_ack)
    begin
      headers = {
        content_type: 'application/json',
        token: nlims_service.token
      }
      url = "#{nlims_service.address}/api/v2/tests/#{results_ack&.tracking_number}/acknowledge_test_results_receipt"
      begin
        order_res = JSON.parse(RestClient.post(url, data.to_json, headers))
        puts "#{order_res['message']} => master ack response"
        next unless order_res['error'] == false

        ackn = ResultsAcknwoledge.find_by(id: results_ack&.id)
        ackn&.acknwoledged_to_nlims = true
        ackn&.save
      rescue StandardError => e
        puts "Error: #{e.message} ==> Acknowledge to master"
      end
    rescue StandardError => e
      puts "Error: #{e.message} ==> Master NLIMS Authentication"
      next
    end
  end
end
