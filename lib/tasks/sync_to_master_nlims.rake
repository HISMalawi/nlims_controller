namespace :master_nlims do
  desc 'TODO'
  task sync_data: :environment do
    # Use NlimsSyncUtilsService to get NLIMS credentials and authentication
    exit if !Config.local_nlims?

    nlims_service = NlimsSyncUtilsService.new(nil)
    last_date = (Date.today - 4.months).to_s
    res = Test.find_by_sql("SELECT specimen.tracking_number as tracking_number, specimen.id as specimen_id,
                      tests.id as test_id,test_type_id as test_type_id, test_types.name as test_name, specimen.couch_id as couch_id
                      FROM tests INNER JOIN specimen ON specimen.id = tests.specimen_id
                      INNER JOIN test_types ON test_types.id = tests.test_type_id
                      WHERE tests.id NOT IN (SELECT test_id FROM test_results where test_id IS NOT NULL)
                      AND DATE(specimen.date_created) > '#{last_date}' AND test_types.name LIKE '%Viral Load%'")
    # Use the service's token for authentication
    if !res.blank? && nlims_service.token.present?
      emr_service = EmrSyncService.new(nil)
      emr_auth_status = [emr_service.token.present?, emr_service.token]
      token = nlims_service.token
      headers = {
        content_type: 'application/json',
        token: token
      }
      res.each do |sample|
        tracking_number = sample['tracking_number']
        test_name = sample['test_name']
        test_id = sample['test_id']
        begin
          url = "#{nlims_service.address}/api/v2/query_order_by_tracking_number/#{tracking_number}?test_name=#{test_name}&couch_id=#{sample['couch_id']}"
          order = JSON.parse(RestClient.get(url, headers))
          next unless order['error'] == false

          tests = order['data']['tests']
          unless order['data']['other']['results'].blank?
            results = order['data']['other']['results']
            results.each do |key, result|
              next unless TestType.find_by(name: key)['id'] == sample['test_type_id']

              result.each do |act_rst|
                measure = act_rst[0]
                measure_id = Measure.find_by(name: measure)['id']
                re_value = act_rst[1]
                TestResult.create(
                  test_id: test_id,
                  measure_id: measure_id,
                  result: re_value['result'],
                  time_entered: re_value['result_date']
                )
                acknwoledge_result_at_facility_level(tracking_number, test_id, re_value['result_date'])
                puts "Result updated for tracking number:  #{tracking_number}"
                next unless emr_auth_status[0] == true

                emr_service.push_result_to_emr(tracking_number, test_id, re_value['result_date'])
                acknwoledge_result_at_emr_level(tracking_number, test_id, re_value['result_date'])
                puts "Pushed result to emr for tracking number: #{tracking_number}"
              end
            end
          end

          tests.each do |test, details|
            test_name = test
            status = details['status']
            unless details['update_details'].blank?
              updater_name = details['update_details']['updater_name']
              updater_id = details['update_details']['updater_id']
              time_updated = details['update_details']['time_updated']
              trail_staus =  details['update_details']['status']
            end
            test_status = status
            test_status = 'test-rejected' if test_status == 'rejected'
            tst_id = TestType.find_by(name: test_name)['id']
            tst_status_id = TestStatus.find_by(name: test_status)['id']
            if already_updated_with_such?(test_id, tst_status_id) == false
              tst_update = Test.find_by(id: test_id, test_type_id: tst_id)
              tst_update.test_status_id = tst_status_id
              tst_update.save
              if status == trail_staus
                TestStatusTrail.create(
                  test_id: test_id,
                  time_updated: time_updated,
                  test_status_id: tst_status_id,
                  who_updated_id: updater_id.to_s,
                  who_updated_name: updater_name.to_s,
                  who_updated_phone_number: ''
                )
              end
              puts "Status updated to #{status} for tracking number: #{tracking_number}"
              if emr_auth_status[0] == true
                emr_service.push_status_to_emr(tracking_number, status, time_updated, test_id)
                puts "Pushed status: #{status} to emr for tracking number: #{tracking_number}"
              end
            else
              puts "Order already updated with such status for tracking number: #{tracking_number}"
            end
          end
        rescue StandardError => e
          puts "Error: #{e}"
          next
        end
      end
    end
    # push_acknwoledgement_to_master_nlims
  end
  task test_syncing: :environment do
    # Use services to get authentication status
    nlims_service = NlimsSyncUtilsService.new(nil)
    emr_service = EmrSyncService.new(nil)
    last_date = (Date.today - 4.months).to_s
    res = Test.find_by_sql("SELECT specimen.tracking_number as tracking_number, specimen.id as specimen_id,
                      tests.id as test_id,test_type_id as test_type_id, test_types.name as test_name
                      FROM tests INNER JOIN specimen ON specimen.id = tests.specimen_id
                      INNER JOIN test_types ON test_types.id = tests.test_type_id
                      WHERE tests.id NOT IN (SELECT test_id FROM test_results where test_id IS NOT NULL)
                      AND DATE(specimen.date_created) > '#{last_date}' AND test_types.name LIKE '%Viral Load%'")

    status = {
      local_nlims_data_available_for_syncing: res.present? ? 'Yes' : 'No',
      nlims_authenticate_with_emr: emr_service.token.present? ? 'Success' : 'Failed',
      nlims_authenticate_with_nlims_chsu: nlims_service.token.present? ? 'Success' : 'Failed'
    }
    puts status
  end
end

def already_updated_with_such?(test_id, test_status)
  res = Test.find_by(id: test_id, test_status_id: test_status)
  return false if res.nil?

  true
end

def push_acknwoledgement_to_master_nlims
  # Use NlimsSyncUtilsService to get NLIMS credentials and authentication
  nlims_service = NlimsSyncUtilsService.new(nil)
  return unless nlims_service.token.present?

  res = ResultsAcknwoledge.find_by_sql("SELECT * FROM results_acknwoledges WHERE acknwoledged_to_nlims ='false'")
  return if res.blank?

  res.each do |order|
    dt = Test.find_by_sql("SELECT test_types.name AS test_name
                        FROM tests
                        INNER JOIN test_types ON test_types.id = tests.test_type_id
                        WHERE tests.id='#{order['test_id']}'
                      ")
    level = TestResultRecepientType.find_by(id: order['acknwoledment_level'])
    level = level['name'] unless level.blank?
    data = {
      'tracking_number': order['tracking_number'],
      'test': dt[0]['test_name'],
      'date_acknowledged': order['acknwoledged_at'],
      'recipient_type': level,
      'acknwoledment_by': order['acknwoledged_by']
    }
    begin
      headers = {
        content_type: 'application/json',
        token: nlims_service.token
      }
      url = "#{nlims_service.address}/api/v1/acknowledge/test/results/recipient"
      begin
        order_res = JSON.parse(RestClient.post(url, data.to_json, headers))
        puts "#{order_res} => master ack response"
        next unless order_res['error'] == false

        ackn = ResultsAcknwoledge.find_by(id: order['id'])
        ackn.acknwoledged_to_nlims = true
        ackn.save
      rescue StandardError => e
        puts "Error: #{e.message} ==> Acknowledge to master"
      end
    rescue StandardError => e
      puts "Error: #{e.message} ==> Master NLIMS Authentication"
      next
    end
  end
end

def acknwoledge_result_at_facility_level(tracking_number, test_id, result_date)
  check = ResultsAcknwoledge.find_by(tracking_number: tracking_number, acknwoledged_by: 'local_nlims_at_facility')
  return unless check.nil?

  ResultsAcknwoledge.create(
    tracking_number: tracking_number,
    test_id: test_id,
    acknwoledged_at: Time.new.strftime('%Y%m%d%H%M%S'),
    result_date: result_date,
    acknwoledged_by: 'local_nlims_at_facility',
    acknwoledged_to_nlims: false,
    acknowledgment_level: 3
  )
  test_ = Test.find_by(id: test_id)
  test_.result_given = 0
  test_.date_result_given = Time.new.strftime('%Y%m%d%H%M%S')
  test_.test_result_receipent_types = 3
  test_.save
end

def acknwoledge_result_at_emr_level(tracking_number, test_id, result_date)
  check = ResultsAcknwoledge.find_by(tracking_number: tracking_number, acknwoledged_by: 'emr_at_facility')
  return unless check.nil?

  ResultsAcknwoledge.create(
    tracking_number: tracking_number,
    test_id: test_id,
    acknwoledged_at: Time.new.strftime('%Y%m%d%H%M%S'),
    result_date: result_date,
    acknwoledged_by: 'emr_at_facility',
    acknwoledged_to_nlims: false,
    acknowledgment_level: 2
  )
end

def authenticate_with_emr
  # Use EmrSyncService for EMR authentication
  emr_service = EmrSyncService.new(nil)
  if emr_service.token.present?
    puts 'EMR authentication successful'
    [true, emr_service.token]
  else
    puts 'EMR authentication failed'
    [false, '']
  end
end
