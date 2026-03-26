#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to sync data from mlab database to nlims database
# This script reads from the mlab database dump loaded on the nlims server
# and syncs orders, tests, statuses, and results to nlims

require File.expand_path('../config/environment', __dir__)
require 'logger'
require 'json'

# Sync service to handle mlab to nlims data migration
class MlabToNlimsSyncService
  BATCH_SIZE = 100 # Reduced from 1000 for better query performance
  NLIMS_STATUS_MAPPING = {
    'pending' => 'pending',
    'specimen-not-collected' => 'specimen_not_collected',
    'specimen_not_collected' => 'specimen_not_collected',
    'drawn' => 'drawn',
    'specimen-collected' => 'specimen_collected',
    'specimen_collected' => 'specimen_collected',
    'specimen-received' => 'specimen_accepted',
    'specimen_received' => 'specimen_accepted',
    'specimen-accepted' => 'specimen_accepted',
    'specimen_accepted' => 'specimen_accepted',
    'specimen-rejected' => 'specimen_rejected',
    'specimen_rejected' => 'specimen_rejected',
    'test-in-progress' => 'started',
    'test_in_progress' => 'started',
    'test-rejected' => 'test-rejected',
    'test_rejected' => 'test-rejected',
    'verified' => 'verified',
    'completed' => 'verified',
    'not-done' => 'not-done',
    'not-received' => 'not-received',
    'not_received' => 'not-received',
    'failed' => 'failed',
    'rejected' => 'rejected',
    'voided' => 'voided',
    'started' => 'started'
  }.freeze

  def initialize(sending_facility: nil, district: nil, start_from_id: nil, limit: nil)
    # Load mlab global settings if facility/district not provided
    mlab_global = MlabGlobal.current

    @sending_facility = sending_facility || mlab_global&.name
    @site_name = @sending_facility # Store for failure tracking
    @district = district || mlab_global&.district
    @start_from_id = start_from_id || 0
    @limit = limit
    @total_processed = 0
    @total_created = 0
    @total_updated = 0
    @total_skipped = 0
    @total_failed = 0
    @stats_by_stage = Hash.new(0)
    @last_processed_test_id = @start_from_id

    # Initialize file logger
    setup_logger
  end

  # Quick retry method for single test without full sync overhead
  # Returns: [:success/:failure/:skipped, message]
  def self.quick_retry_test(mlab_test_id, sending_facility: nil)
    # Create a minimal instance without logger overhead
    service = new(sending_facility: sending_facility, start_from_id: 0, limit: 1)
    service.instance_variable_set(:@logger, nil) # Disable file logging for speed

    # Load the test with necessary associations
    mlab_test = MlabTest.not_voided
                        .includes(
                          :mlab_test_type,
                          :mlab_specimen,
                          :mlab_status,
                          :mlab_test_statuses,
                          :mlab_test_results,
                          mlab_order: [
                            :mlab_status,
                            :mlab_order_statuses,
                            { mlab_encounter: { mlab_client: [:mlab_person,
                                                              { mlab_client_identifiers: :mlab_client_identifier_type }] } }
                          ]
                        )
                        .find_by(id: mlab_test_id)

    return [:skipped, 'Test not found in mlab database'] unless mlab_test

    # Process the test directly, capturing result
    begin
      service.send(:process_test_for_retry, mlab_test)
    rescue StandardError => e
      [:failure, "Error: #{e.message}"]
    end
  end

  def run
    puts '=' * 80
    puts 'MLAB TO NLIMS DATA SYNC'
    puts '=' * 80
    puts "Start Time: #{Time.current}"
    puts "Sending Facility: #{@sending_facility || 'Using facility from mlab data'}"
    puts "District: #{@district || 'Not specified'}"
    puts "Starting from Test ID: #{@start_from_id}"
    puts "Batch Size: #{BATCH_SIZE}"
    puts '=' * 80
    puts ''

    # Log sync start
    log_to_file('=' * 80)
    log_to_file("SYNC STARTED: #{Time.current}")
    log_to_file("Facility: #{@sending_facility}, District: #{@district}")
    log_to_file("Starting from Test ID: #{@start_from_id}, Limit: #{@limit || 'None'}")
    log_to_file('=' * 80)

    # Count total tests to sync
    total_tests = count_total_tests
    puts "Total tests to sync: #{total_tests}"
    log_to_file("Total tests to sync: #{total_tests}")
    puts ''

    # Process in batches
    offset = 0
    batch_number = 1

    loop do
      puts "\n[#{Time.current.strftime('%H:%M:%S')}] Fetching batch ##{batch_number}..."
      fetch_start = Time.now
      tests_batch = fetch_tests_batch(offset)
      fetch_time = Time.now - fetch_start

      break if tests_batch.empty?

      puts "[#{Time.current.strftime('%H:%M:%S')}] Fetched #{tests_batch.size} tests in #{fetch_time.round(2)}s"
      puts "\n--- Processing Batch ##{batch_number} (Records #{offset + 1}-#{offset + tests_batch.size}) ---"
      log_to_file("Batch ##{batch_number}: Processing #{tests_batch.size} tests (offset #{offset})")

      process_start = Time.now
      process_batch(tests_batch)
      process_time = Time.now - process_start
      puts "[#{Time.current.strftime('%H:%M:%S')}] Processed batch in #{process_time.round(2)}s"
      log_to_file("Batch ##{batch_number}: Completed in #{process_time.round(2)}s")

      offset += BATCH_SIZE
      batch_number += 1

      # Show progress
      percentage = ((offset.to_f / total_tests) * 100).round(2)
      puts "Progress: #{offset}/#{total_tests} (#{percentage}%)"
      puts "Created: #{@total_created}, Updated: #{@total_updated}, Skipped: #{@total_skipped}, Failed: #{@total_failed}"

      # Break if we've reached the limit
      break if @limit && offset >= @limit
      break if offset >= total_tests
    end

    print_summary
  end

  private

  def count_total_tests
    query = MlabTest.not_voided
                    .joins(:mlab_order, :mlab_test_type)
                    .where('tests.id > ?', @start_from_id)
                    .where('orders.voided IS NULL OR orders.voided = 0')

    query = query.limit(@limit) if @limit
    query.count
  end

  def fetch_tests_batch(offset)
    # Calculate batch size based on limit
    batch_size = if @limit
                   # Don't fetch more than the limit allows
                   [BATCH_SIZE, @limit - offset].min
                 else
                   BATCH_SIZE
                 end

    # Simplified eager loading to avoid massive JOINs
    # Load only essential associations, allow some N+1 queries for better performance
    MlabTest.not_voided
            .joins(:mlab_order, :mlab_test_type)
            .includes(
              :mlab_test_type,
              :mlab_specimen,
              :mlab_status,
              mlab_order: [
                :mlab_status,
                { mlab_encounter: { mlab_client: [:mlab_person,
                                                  { mlab_client_identifiers: :mlab_client_identifier_type }] } }
              ]
            )
            .where('tests.id > ?', @start_from_id)
            .where('orders.voided IS NULL OR orders.voided = 0')
            .order('tests.id ASC')
            .offset(offset)
            .limit(batch_size)
  end

  def process_batch(tests_batch)
    batch_start = Time.now
    tests_batch.each_with_index do |mlab_test, index|
      @total_processed += 1
      @last_processed_test_id = mlab_test.id

      # Show progress every 25 tests (since batch is smaller now)
      if (index + 1) % 25 == 0
        elapsed = Time.now - batch_start
        avg_time = elapsed / (index + 1)
        remaining = (tests_batch.size - index - 1) * avg_time
        puts "  [Progress: #{index + 1}/#{tests_batch.size} tests, ~#{remaining.round(1)}s remaining]"

        # Log progress
        log_to_file("Progress: Last Test ID #{@last_processed_test_id}, Total: #{@total_processed}, Created: #{@total_created}, Updated: #{@total_updated}, Skipped: #{@total_skipped}, Failed: #{@total_failed}")
        log_progress
      end

      process_test(mlab_test)
    rescue StandardError => e
      @total_failed += 1
      log_to_file("ERROR: Test ID #{mlab_test.id} - #{e.message}")
      log_failure(
        mlab_test_id: mlab_test.id,
        tracking_number: mlab_test.mlab_order&.tracking_number,
        test_type_nlims_code: mlab_test.mlab_test_type&.nlims_code,
        stage: 'batch_processing',
        reason: "Unexpected error: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}",
        payload: nil
      )
      puts "  ✗ Test ID #{mlab_test.id}: FAILED - #{e.message}"
    end

    # Log progress at end of batch
    log_progress
  end

  def process_test(mlab_test)
    # Build the payload from mlab test data
    payload = build_payload_from_mlab_test(mlab_test)

    if payload[:test_type_nlims_code].blank?
      return skip_test(mlab_test, 'Missing test type nlims_code',
                       tracking_number: payload[:tracking_number],
                       test_type_nlims_code: payload[:test_type_nlims_code],
                       payload: payload)
    end
    if payload[:tracking_number].blank?
      return skip_test(mlab_test, 'Missing tracking number',
                       tracking_number: payload[:tracking_number],
                       test_type_nlims_code: payload[:test_type_nlims_code],
                       payload: payload)
    end

    # Check if order already exists
    existing_order = Speciman.find_by(tracking_number: payload[:tracking_number])

    if existing_order
      # Order exists, check if test exists
      process_existing_order(mlab_test, existing_order, payload)
    else
      # Create new order with test
      create_new_order_with_test(mlab_test, payload)
    end
  end

  # Lightweight version of process_test that returns status instead of tracking stats
  # Returns: [:success/:failure/:skipped, message]
  def process_test_for_retry(mlab_test)
    # Build the payload from mlab test data
    payload = build_payload_from_mlab_test(mlab_test)

    return [:skipped, 'Missing test type nlims_code'] if payload[:test_type_nlims_code].blank?
    return [:skipped, 'Missing tracking number'] if payload[:tracking_number].blank?

    # Check if order already exists
    existing_order = Speciman.find_by(tracking_number: payload[:tracking_number])

    if existing_order
      # Order exists, check if test exists
      process_existing_order_for_retry(mlab_test, existing_order, payload)

    else
      # Create new order with test
      create_new_order_with_test_for_retry(mlab_test, payload)

    end
  rescue StandardError => e
    [:failure, e.message]
  end

  def process_existing_order_for_retry(_mlab_test, existing_order, payload)
    # Update order's sending facility and district if provided
    update_order_facility_and_district(existing_order, payload)

    # Check if test exists for this order
    existing_test = Test.joins(:test_type)
                        .where(
                          specimen_id: existing_order.id,
                          test_types: { nlims_code: payload[:test_type_nlims_code] }
                        ).first

    if existing_test
      # Test exists, update status and results if needed
      test_data = payload[:tests].first
      status, response = TestManagement::TestsService.update_tests(
        Speciman.find(existing_test.specimen_id),
        test_data
      )

      if status
        [:success, "Updated existing test (NLIMS ID: #{existing_test.id})"]
      else
        [:skipped, "Update skipped: #{response}"]
      end
    else
      # Test doesn't exist, add it to the order
      test_data = payload[:tests].first
      status, response = TestManagement::TestsService.add_test_to_order(existing_order, test_data)

      return [:failure, "Failed to add test: #{response}"] unless status

      status, response = TestManagement::TestsService.update_tests(existing_order, test_data)

      if status
        [:success, 'Test added to existing order']
      else
        [:failure, "Test creation failed: #{response}"]
      end
    end
  end

  def create_new_order_with_test_for_retry(_mlab_test, payload)
    status, response = OrderManagement::OrdersService.create_order(
      build_order_params(payload),
      false
    )

    if status
      TestManagement::TestsService.update_tests(
        Speciman.find_by(tracking_number: payload[:tracking_number]),
        payload[:tests].first
      )
      [:success, "Order created (Tracking: #{response})"]
    else
      [:failure, "Order creation failed: #{response}"]
    end
  end

  def process_existing_order(mlab_test, existing_order, payload)
    # Update order's sending facility and district if provided
    update_order_facility_and_district(existing_order, payload)

    # Check if test exists for this order
    existing_test = Test.joins(:test_type)
                        .where(
                          specimen_id: existing_order.id,
                          test_types: { nlims_code: payload[:test_type_nlims_code] }
                        ).first

    if existing_test
      # Test exists, update status and results if needed
      update_existing_test(mlab_test, existing_test, payload)
    else
      # Test doesn't exist, add it to the order
      add_test_to_existing_order(mlab_test, existing_order, payload)
    end
  end

  def update_existing_test(mlab_test, existing_test, payload)
    test_data = payload[:tests].first # Get test details from tests array

    puts '    Updating test using TestsService...'
    # Use the same service method that the API uses
    status, response = TestManagement::TestsService.update_tests(
      Speciman.find(existing_test.specimen_id),
      test_data
    )

    if status
      @total_updated += 1
      @stats_by_stage['test_updated'] += 1
      puts "  ↻ Test ID #{mlab_test.id}: Updated (NLIMS Test ID: #{existing_test.id}) - #{response}"
    else
      @total_skipped += 1
      puts "  → Test ID #{mlab_test.id}: Update skipped - #{response}"
    end
  rescue StandardError => e
    @total_failed += 1
    log_failure(
      mlab_test_id: mlab_test.id,
      tracking_number: payload[:tracking_number],
      test_type_nlims_code: payload[:test_type_nlims_code],
      stage: 'test_update',
      reason: e.message,
      payload: payload
    )
    puts "  ✗ Test ID #{mlab_test.id}: Update FAILED - #{e.message}"
  end

  def add_test_to_existing_order(mlab_test, existing_order, payload)
    # Get test details from tests array
    test_data = payload[:tests].first

    puts '    Adding test to existing order using TestsService...'

    # Use the same service methods that the API uses
    status, response = TestManagement::TestsService.add_test_to_order(existing_order, test_data)

    unless status
      return skip_test(mlab_test, "Failed to add test: #{response}",
                       tracking_number: payload[:tracking_number],
                       test_type_nlims_code: payload[:test_type_nlims_code],
                       payload: payload)
    end

    # Now update the test with status trail and results
    status, response = TestManagement::TestsService.update_tests(existing_order, test_data)

    if status
      @total_created += 1
      @stats_by_stage['test_added'] += 1
      new_test = Test.joins(:test_type).where(
        specimen_id: existing_order.id,
        test_types: { nlims_code: payload[:test_type_nlims_code] }
      ).first
      puts "  + Test ID #{mlab_test.id}: Test Added to Existing Order (NLIMS Test ID: #{new_test&.id})"
    else
      @total_failed += 1
      log_failure(
        mlab_test_id: mlab_test.id,
        tracking_number: payload[:tracking_number],
        test_type_nlims_code: payload[:test_type_nlims_code],
        stage: 'test_creation',
        reason: response,
        payload: payload
      )
      puts "  ✗ Test ID #{mlab_test.id}: Test update after creation FAILED - #{response}"
    end
  rescue StandardError => e
    @total_failed += 1
    log_failure(
      mlab_test_id: mlab_test.id,
      tracking_number: payload[:tracking_number],
      test_type_nlims_code: payload[:test_type_nlims_code],
      stage: 'test_creation',
      reason: e.message,
      payload: payload
    )
    puts "  ✗ Test ID #{mlab_test.id}: Test Creation FAILED - #{e.message}"
  end

  def create_new_order_with_test(mlab_test, payload)
    # Create order using OrderManagement::OrdersService
    status, response = OrderManagement::OrdersService.create_order(
      build_order_params(payload),
      false # not an order request
    )

    if status
      TestManagement::TestsService.update_tests(Speciman.find_by(tracking_number: payload[:tracking_number]),
                                                payload[:tests].first)
      @total_created += 1
      @stats_by_stage['order_created'] += 1
      puts "  ✓ Test ID #{mlab_test.id}: Order Created (Tracking: #{response})"
    else
      @total_failed += 1
      log_failure(
        mlab_test_id: mlab_test.id,
        tracking_number: payload[:tracking_number],
        test_type_nlims_code: payload[:test_type_nlims_code],
        stage: 'order_creation',
        reason: response,
        payload: payload
      )
      puts "  ✗ Test ID #{mlab_test.id}: Order Creation FAILED - #{response}"
    end
  rescue StandardError => e
    @total_failed += 1
    log_failure(
      mlab_test_id: mlab_test.id,
      tracking_number: payload[:tracking_number],
      test_type_nlims_code: payload[:test_type_nlims_code],
      stage: 'order_creation',
      reason: e.message,
      payload: payload
    )
    puts "  ✗ Test ID #{mlab_test.id}: Order Creation FAILED - #{e.message}"
  end

  def build_payload_from_mlab_test(mlab_test)
    order = mlab_test.mlab_order
    encounter = order&.mlab_encounter
    client = encounter&.mlab_client
    person = client&.mlab_person
    specimen = mlab_test.mlab_specimen
    test_type = mlab_test.mlab_test_type

    # Build patient data
    patient = {
      national_patient_id: get_patient_npid(client),
      first_name: person&.first_name,
      last_name: person&.last_name,
      gender: person&.sex == 'M' ? 'Male' : 'Female',
      date_of_birth: person&.date_of_birth
    }

    # Build order data
    facility_name = @sending_facility || encounter&.mlab_facility&.name

    # Get clinical data from client identifiers
    clinical_data = get_clinical_data_from_identifiers(client)

    order_data = {
      uuid: SecureRandom.uuid,
      tracking_number: order&.tracking_number,
      district: get_district_from_facility(facility_name),
      sending_facility: facility_name,
      sample_type: build_sample_type(specimen),
      priority: order&.mlab_priority&.name || 'Routine',
      drawn_by: {
        id: order&.creator || 1,
        name: order&.collected_by || "#{get_user_details(order&.creator)[:first_name]} #{get_user_details(order&.creator)[:last_name]}",
        phone_number: ''
      },
      date_created: order&.created_date || mlab_test.created_date,
      sample_status: build_sample_status(order),
      target_lab: facility_name,
      order_location: facility_name || encounter&.mlab_facility&.name,
      requested_by: order&.requested_by,
      art_start_date: clinical_data['art_start_date'],
      arv_number: clinical_data['arv_number'] || 'N/A',
      art_regimen: clinical_data['art_regimen'] || 'N/A',
      clinical_history: clinical_data.to_json,
      status_trail: build_order_status_trail(order),
      source_system: 'IBLIS'
    }

    # Build test data
    # NOTE: Uses nlims_code from mlab for all lookups:
    # - test_type.nlims_code for test type matching
    # - test_indicator.nlims_code for measure/indicator matching

    # Get the latest test status and its timestamp
    latest_status = mlab_test.mlab_test_statuses.not_voided.order(created_date: :desc).first
    status_trail = build_test_status_trail(mlab_test)

    test_data = {
      test_type: {
        nlims_code: test_type&.nlims_code,
        name: test_type&.name,
        method_of_testing: mlab_test.method_of_testing
      },
      test_status: get_latest_test_status(mlab_test),
      time_updated: latest_status&.created_date || mlab_test.created_date,
      status_trail: status_trail,
      test_results: build_test_results(mlab_test)
    }

    {
      order: order_data,
      patient: patient,
      tests: [test_data],
      tracking_number: order&.tracking_number,
      test_type_nlims_code: test_type&.nlims_code,
      time_created: mlab_test.created_date,
      drawn_by: order&.collected_by || "#{get_user_details(order&.creator)[:first_name]} #{get_user_details(order&.creator)[:last_name]}",
      method_of_testing: mlab_test.method_of_testing
    }
  end

  def build_order_params(payload)
    {
      order: payload[:order],
      patient: payload[:patient],
      tests: payload[:tests]
    }
  end

  def build_sample_type(specimen)
    # Use nlims_code from mlab specimen for accurate matching
    # NOTE: In mlab, specimens table = nlims specimen_types table
    {
      nlims_code: specimen&.nlims_code,
      name: specimen&.name
    }
  end

  def build_sample_status(order)
    # Use status_id directly from order instead of querying order_statuses table
    status_name = order&.mlab_status&.name || 'specimen-not-collected'

    {
      name: map_status_name(status_name)
    }
  end

  def build_order_status_trail(order)
    return [] unless order

    order.mlab_order_statuses.not_voided.order(:created_date).map do |status|
      user_details = get_user_details(status.creator)
      {
        status: map_status_name(status.mlab_status&.name),
        timestamp: status.created_date,
        updated_by: {
          'id' => status.creator,
          'first_name' => user_details[:first_name],
          'last_name' => user_details[:last_name],
          'phone_number' => user_details[:phone_number]
        }
      }
    end
  end

  def build_test_status_trail(mlab_test)
    mlab_test.mlab_test_statuses.not_voided.order(:created_date).map do |status|
      user_details = get_user_details(status.creator)
      {
        status: map_status_name(status.mlab_status&.name),
        timestamp: status.created_date,
        updated_by: {
          'id' => status.creator,
          'first_name' => user_details[:first_name],
          'last_name' => user_details[:last_name],
          'phone_number' => user_details[:phone_number]
        }
      }
    end
  end

  def build_test_results(mlab_test)
    # Uses nlims_code from mlab test_indicator for accurate measure matching
    # Unit comes from test_type_test_indicators join table via result.unit method
    mlab_test.mlab_test_results.not_voided.map do |result|
      {
        measure: {
          nlims_code: result.mlab_test_indicator&.nlims_code,
          name: result.mlab_test_indicator&.name
        },
        result: {
          value: result.value,
          unit: result.unit,
          result_date: result.result_date || result.created_date,
          platform: result.machine_name || '',
          platformserial: ''
        }
      }
    end
  end

  def get_latest_test_status(mlab_test)
    # Use status_id directly from test instead of querying test_statuses table
    map_status_name(mlab_test.mlab_status&.name || 'pending')
  end

  def get_patient_npid(client)
    # Try to get NPID from client identifiers
    # This is a placeholder - adjust based on actual mlab structure
    client&.uuid
  end

  def update_order_facility_and_district(existing_order, payload)
    # Update sending facility and district if they differ from sync source
    facility_name = payload.dig(:order, :sending_facility)
    district = payload.dig(:order, :district)

    updated = false

    if facility_name.present? && existing_order.sending_facility != facility_name
      existing_order.update_column(:sending_facility, facility_name)
      updated = true
    end

    if district.present? && existing_order.district != district
      existing_order.update_column(:district, district)
      updated = true
    end

    puts '    ℹ Updated order facility/district' if updated
  rescue StandardError => e
    puts "    ⚠ Failed to update order facility/district: #{e.message}"
  end

  def get_district_from_facility(_facility_name)
    # Use district provided at initialization, or default
    @district
  end

  def get_user_details(user_id)
    return { first_name: 'MLAB', last_name: 'Sync', phone_number: '' } if user_id.nil?

    # Cache users to avoid repeated database queries
    @user_cache ||= {}
    return @user_cache[user_id] if @user_cache.key?(user_id)

    user = MlabUser.includes(:mlab_person).find_by(id: user_id)
    if user && user.mlab_person
      person = user.mlab_person
      @user_cache[user_id] = {
        first_name: person.first_name || 'MLAB',
        last_name: person.last_name || 'User',
        phone_number: '' # Phone number not stored in mlab people table
      }
    else
      @user_cache[user_id] = { first_name: 'MLAB', last_name: 'Sync', phone_number: '' }
    end

    @user_cache[user_id]
  end

  def map_status_name(mlab_status)
    return 'drawn' if mlab_status.blank?

    # Try to map the status, or use it as-is with hyphens converted to underscores
    # The actual validation happens when we look up the status in NLIMS database
    normalized_status = mlab_status.downcase.strip
    NLIMS_STATUS_MAPPING[normalized_status] || normalized_status.tr('-', '_')
  end

  def get_clinical_data_from_identifiers(client)
    return {} unless client

    # Cache to avoid repeated queries
    @identifier_cache ||= {}
    cache_key = "client_#{client.id}"
    return @identifier_cache[cache_key] if @identifier_cache.key?(cache_key)

    # Load all identifiers for this client with their types
    identifiers = client.mlab_client_identifiers
                        .not_voided
                        .includes(:mlab_client_identifier_type)

    # Build a hash of identifier_type_name => value
    identifier_data = {}
    identifiers.each do |identifier|
      type_name = identifier.mlab_client_identifier_type&.name
      identifier_data[type_name] = identifier.value if type_name
    end

    # Extract clinical data
    clinical_data = {
      'art_start_date' => identifier_data['art_start_date'],
      'arv_number' => identifier_data['art_number'],
      'art_regimen' => identifier_data['art_regimen']
    }

    @identifier_cache[cache_key] = clinical_data
    clinical_data
  end

  def skip_test(mlab_test, reason, tracking_number: nil, test_type_nlims_code: nil, payload: nil)
    @total_skipped += 1
    @stats_by_stage['skipped'] += 1
    puts "  → Test ID #{mlab_test.id}: Skipped - #{reason}"

    # Log skipped tests as failures for investigation
    log_failure(
      mlab_test_id: mlab_test.id,
      tracking_number: tracking_number,
      test_type_nlims_code: test_type_nlims_code,
      stage: 'skipped',
      reason: reason,
      payload: payload
    )
  end

  def log_failure(mlab_test_id:, tracking_number:, test_type_nlims_code:, stage:, reason:, payload:)
    MlabSyncFailure.log_failure(
      mlab_test_id: mlab_test_id,
      tracking_number: tracking_number,
      test_type_nlims_code: test_type_nlims_code,
      site_name: @site_name,
      stage: stage,
      reason: reason,
      payload: payload
    )
  end

  def setup_logger
    log_dir = Rails.root.join('log')
    log_file = log_dir.join('mlab_sync.log')

    @logger = Logger.new(log_file, 'daily')
    @logger.level = Logger::INFO
    @logger.formatter = proc do |severity, datetime, _progname, msg|
      "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
    end
  end

  def log_to_file(message)
    @logger&.info(message)
  end

  def log_progress
    # Write current progress to a checkpoint file
    checkpoint_file = Rails.root.join('log', 'mlab_sync_checkpoint.txt')
    File.write(checkpoint_file, {
      last_test_id: @last_processed_test_id,
      total_processed: @total_processed,
      total_created: @total_created,
      total_updated: @total_updated,
      total_skipped: @total_skipped,
      total_failed: @total_failed,
      timestamp: Time.current.to_s
    }.to_json)
  end

  def print_summary
    puts "\n"
    puts '=' * 80
    puts 'SYNC COMPLETED'
    puts '=' * 80
    puts "End Time: #{Time.current}"
    puts "Total Processed: #{@total_processed}"
    puts "Total Created: #{@total_created}"
    puts "Total Updated: #{@total_updated}"
    puts "Total Skipped: #{@total_skipped}"
    puts "Total Failed: #{@total_failed}"
    puts ''
    puts 'Breakdown by Stage:'
    @stats_by_stage.each do |stage, count|
      puts "  #{stage}: #{count}"
    end
    puts '=' * 80
    puts ''

    # Log final summary
    log_to_file('=' * 80)
    log_to_file("SYNC COMPLETED: #{Time.current}")
    log_to_file("Last Test ID Processed: #{@last_processed_test_id}")
    log_to_file("Total Processed: #{@total_processed}")
    log_to_file("Created: #{@total_created}, Updated: #{@total_updated}, Skipped: #{@total_skipped}, Failed: #{@total_failed}")
    log_to_file('=' * 80)
    log_progress # Final checkpoint

    total_issues = @total_failed + @total_skipped
    return unless total_issues > 0

    puts "⚠ There were #{@total_failed} failed and #{@total_skipped} skipped records (total: #{total_issues})."
    puts '  All issues are logged in mlab_sync_failures table for investigation.'
    puts '  Run: SELECT * FROM mlab_sync_failures WHERE resolved = 0 ORDER BY created_at DESC;'
    log_to_file("WARNING: #{total_issues} total issues (#{@total_failed} failed, #{@total_skipped} skipped)")
  end
end

# Main execution
if $PROGRAM_NAME == __FILE__
  puts 'MLAB to NLIMS Sync Script'
  puts ''

  # Load mlab global settings to show defaults
  mlab_global = MlabGlobal.current
  default_facility = mlab_global&.name || 'From mlab encounter data'
  default_district = mlab_global&.district || 'Not set'

  # Ask for sending facility
  print "Enter sending facility name (leave blank to use global setting: #{default_facility}): "
  sending_facility = gets.chomp
  sending_facility = nil if sending_facility.empty?

  # Ask for district
  print "Enter district name (leave blank to use global setting: #{default_district}): "
  district = gets.chomp
  district = nil if district.empty?

  # Ask for starting ID
  print 'Enter starting test ID (default: 0): '
  start_id = gets.chomp
  start_id = start_id.empty? ? 0 : start_id.to_i

  # Ask for limit
  print 'Enter maximum number of tests to process (leave blank for all): '
  limit = gets.chomp
  limit = limit.empty? ? nil : limit.to_i

  # Confirmation
  puts ''
  puts 'Configuration:'
  puts "  Sending Facility: #{sending_facility || default_facility}"
  puts "  District: #{district || default_district}"
  puts "  Starting from Test ID: #{start_id}"
  puts "  Limit: #{limit || 'No limit'}"
  puts ''
  print 'Proceed with sync? (yes/no): '
  confirmation = gets.chomp.downcase

  if %w[yes y].include?(confirmation)
    sync_service = MlabToNlimsSyncService.new(
      sending_facility: sending_facility,
      district: district,
      start_from_id: start_id,
      limit: limit
    )
    sync_service.run
  else
    puts 'Sync cancelled.'
  end
end
