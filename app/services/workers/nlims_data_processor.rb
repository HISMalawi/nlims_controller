# frozen_string_literal: true

##
# Shared module for processing NLIMS data
# Extracts common functionality used by multiple workers
module NlimsDataProcessor
  ##
  # Pulls and processes data from master NLIMS
  # Fetches orders, updates tests, and syncs to EMR
  def pull_and_process_data(tests)
    nlims_service = authenticate_nlims
    return unless nlims_service

    return if tests.blank?

    emr_service = authenticate_emr
    headers = build_headers(nlims_service.token)

    tests.each do |sample|
      process_sample(sample, nlims_service, emr_service, headers)
    end
  end

  ##
  # Pushes acknowledgements to master NLIMS
  # Uses existing NlimsSyncUtilsService instead of reimplementing
  def push_acknowledgements
    nlims_service = authenticate_nlims
    return unless nlims_service

    Rails.logger.info('Pushing acknowledgements to master NLIMS')

    # Use existing service method which handles all the logic
    nlims_service.push_acknwoledgement_to_master_nlims
  rescue StandardError => e
    Rails.logger.error("Error pushing acknowledgements: #{e.class} - #{e.message}")
  end

  private

  def authenticate_nlims
    nlims_service = NlimsSyncUtilsService.new(nil)
    auth_success = nlims_service.token.present?
    Rails.logger.info("NLIMS authentication: #{auth_success ? 'Success' : 'Failed'}")

    auth_success ? nlims_service : nil
  end

  def authenticate_emr
    emr_service = EmrSyncService.new(nil)
    auth_success = emr_service.token.present?
    Rails.logger.info("EMR authentication: #{auth_success ? 'Success' : 'Failed'}")

    emr_service
  end

  def build_headers(token)
    {
      content_type: 'application/json',
      token: token
    }
  end

  def process_sample(sample, nlims_service, emr_service, headers)
    tracking_number = sample[:tracking_number]
    couch_id = sample[:couch_id]

    order = fetch_order_from_nlims(tracking_number, couch_id, nlims_service, headers)
    return unless order

    tests = order.deep_symbolize_keys[:data][:tests]
    lab_order = Speciman.find_by(tracking_number: tracking_number)

    tests.each do |lab_test|
      process_lab_test(lab_test, lab_order, emr_service, tracking_number)
    end
  rescue StandardError => e
    Rails.logger.error("Error processing sample #{tracking_number}: #{e.message}")
  end

  def fetch_order_from_nlims(tracking_number, couch_id, nlims_service, headers)
    url = "#{nlims_service.address}/api/v2/orders/#{tracking_number}?couch_id=#{couch_id}"
    order = JSON.parse(RestClient.get(url, headers))

    return nil if order['error'] != false

    order
  end

  def process_lab_test(lab_test, lab_order, emr_service, tracking_number)
    Rails.logger.info("Updating test for tracking number: #{tracking_number}")

    status, response = TestManagement::TestsService.update_tests(lab_order, lab_test)
    return unless status == true

    Rails.logger.info("Test updated for tracking number: #{tracking_number} --- Response: #{response}")
    return if lab_order&.source_system&.downcase == 'iblis'

    update_emr_for_test(lab_test, lab_order, emr_service)
  end

  def update_emr_for_test(lab_test, lab_order, emr_service)
    lab_test_obj = find_lab_test_object(lab_test, lab_order)
    return unless lab_test_obj

    Rails.logger.info("Updating EMR for tracking number: #{lab_order&.tracking_number}")

    push_status_to_emr(lab_test_obj, lab_order, emr_service)
    push_results_to_emr(lab_test_obj, lab_order, emr_service)

    Rails.logger.info("EMR updated for tracking number: #{lab_order&.tracking_number}")
  end

  def find_lab_test_object(lab_test, lab_order)
    Test.joins(:test_type)
        .where(
          specimen_id: lab_order.id,
          test_types: { nlims_code: lab_test.dig(:test_type, :nlims_code) }
        ).first
  end

  def push_status_to_emr(lab_test_obj, lab_order, emr_service)
    StatusSyncTracker.where(
      tracking_number: lab_order&.tracking_number,
      test_id: lab_test_obj.id,
      app: 'emr'
    ).each do |status_tracker|
      emr_service.push_status_to_emr(
        lab_order.tracking_number,
        status_tracker.status,
        status_tracker.created_at,
        lab_test_obj.id
      )
    end
  end

  def push_results_to_emr(lab_test_obj, lab_order, emr_service)
    test_result = TestResult.find_by(test_id: lab_test_obj.id)
    return unless test_result.present?

    emr_service.push_result_to_emr(
      lab_order&.tracking_number,
      lab_test_obj.id,
      test_result&.time_entered
    )
  end
end
