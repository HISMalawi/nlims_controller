# frozen_string_literal: true

# MIGRATION SCRIPT - IBLIS to NLIMS Data Migration
#
# USAGE:
#   ruby bin/mlab/migrate_data.rb
#
# PARALLEL PROCESSING (recommended for large datasets):
#   To speed up migration, run multiple instances in different terminals with datetime ranges:
#
#   Terminal 1: 2024-01-01 00:00:00 to 2024-03-31 23:59:59 (Q1)
#   Terminal 2: 2024-04-01 00:00:00 to 2024-06-30 23:59:59 (Q2)
#   Terminal 3: 2024-07-01 00:00:00 to 2024-09-30 23:59:59 (Q3)
#   Terminal 4: 2024-10-01 00:00:00 to 2024-12-31 23:59:59 (Q4)
#
#   Or split by hours within a single day:
#   Terminal 1: 2024-01-15 00:00:00 to 2024-01-15 05:59:59
#   Terminal 2: 2024-01-15 06:00:00 to 2024-01-15 11:59:59
#   Terminal 3: 2024-01-15 12:00:00 to 2024-01-15 17:59:59
#   Terminal 4: 2024-01-15 18:00:00 to 2024-01-15 23:59:59
#
#   Each instance will process its own datetime range independently.
#   Make sure datetime ranges don't overlap to avoid race conditions.

TRANSACTION_BATCH_SIZE = 50 # Commit every 50 orders instead of every order
GLOBAL_FACILITY = begin
  MlabBase.find_by_sql('SELECT name, district FROM globals WHERE retired = 0').first
rescue StandardError
  nil
end
VL_TEST_TYPE = TestType.find_by(nlims_code: 'NLIMS_TT_0071_MWI')

# Reference data caches - load once, use many times
SPECIMEN_STATUS_CACHE = SpecimenStatus.all.index_by(&:name)
SPECIMEN_TYPE_CACHE = SpecimenType.all.index_by(&:nlims_code)
TEST_TYPE_CACHE = TestType.all.index_by(&:nlims_code)
TEST_STATUS_CACHE = TestStatus.all.index_by(&:name)
MEASURE_CACHE = Measure.all.group_by(&:nlims_code)
TESTTYPE_MEASURE_CACHE = TesttypeMeasure.all.group_by(&:test_type_id)

USER_CACHE = Hash.new do |h, creator_id|
  h[creator_id] = begin
    if creator_id.nil?
      return { id: nil, first_name: 'Unknown', last_name: 'User', phone_number: nil, full_name: 'Unknown User' }
    end

    # Use string interpolation with sanitized ID (integer is safe from SQL injection)
    user = MlabBase.find_by_sql(<<~SQL).first
      SELECT u.id, p.first_name, p.last_name
      FROM users u
      INNER JOIN people p ON p.id = u.person_id
      WHERE u.id = #{creator_id.to_i}
    SQL

    if user
      {
        id: user.id,
        first_name: user.first_name,
        last_name: user.last_name,
        phone_number: nil,
        full_name: "#{user.first_name} #{user.last_name}"
      }
    else
      { id: nil, first_name: 'Unknown', last_name: 'User', phone_number: nil, full_name: 'Unknown User' }
    end
  end
end

# IBLIS METHODS
def iblis_order(order)
  order_creator = updated_by_for_status_trail(order[:creator])
  tests = iblis_tests_for_order(order)
  encounter = iblis_encounters_for_order(order)
  {
    order: {
      tracking_number: order&.tracking_number,
      order_uuid: order&.uuid,
      sample_type: tests.first[:sample_type],
      sample_status: encounter[:order_status],
      order_location: encounter[:order_location],
      date_created: order&.created_date,
      priority: encounter[:priority],
      reason_for_test: encounter[:priority],
      drawn_by: {
        id: order_creator[:id],
        name: order_creator[:full_name],
        phone_number: ''
      },
      target_lab: GLOBAL_FACILITY&.name,
      sending_facility: GLOBAL_FACILITY&.name,
      district: GLOBAL_FACILITY&.district,
      requested_by: order&.requested_by,
      art_start_date: nil,
      arv_number: nil,
      art_regimen: nil,
      client_history: encounter[:client_history],
      lab_location: tests.first[:order_location],
      source_system: 'IBLIS',
      status_trail: iblis_order_status_trail_for_order(order)
    },
    patient: iblis_patient(encounter[:client_id]),
    tests: tests
  }
end

def iblis_global_facility
  global_facility = MlabBase.find_by_sql <<~SQL
    SELECT
      f.id,
      f.name,
      f.district
    FROM globals f WHERE retired = 0
  SQL
  {
    name: global_facility&.first&.name,
    district: global_facility&.first&.district
  }
end

def iblis_encounters_for_order(order)
  encounters = MlabBase.find_by_sql <<~SQL
    SELECT
      e.id,
      e.client_id,
      et.name AS encounter_type,
      fs.name AS order_location,
      s.name AS order_status,
      pr.name AS order_priority,
      e.client_history
    FROM orders o
    INNER JOIN encounters e ON e.id = o.encounter_id
    INNER JOIN statuses s ON s.id = o.status_id
    INNER JOIN priorities pr ON pr.id = o.priority_id
    LEFT JOIN encounter_types et ON et.id = e.encounter_type_id
    LEFT JOIN facility_sections fs ON fs.id = e.facility_section_id
    WHERE o.id = #{order.id}
  SQL

  encounters.map do |encounter|
    {
      id: encounter&.id,
      client_id: encounter&.client_id,
      encounter_type: encounter&.encounter_type,
      order_location: encounter&.order_location,
      priority: encounter&.order_priority,
      client_history: encounter&.client_history,
      order_status: encounter&.order_status&.gsub('-', '_')
    }
  end.first
end

def iblis_patient(client_id)
  patient = MlabBase.find_by_sql <<~SQL
    SELECT
      p.id,
      p.first_name,
      p.last_name,
      p.date_of_birth,
      p.sex AS gender,
      ci.value AS national_patient_id
    FROM clients c
    INNER JOIN people p ON p.id = c.person_id
    LEFT JOIN client_identifiers ci ON ci.client_id = c.id
    LEFT JOIN client_identifier_types cit ON cit.id = ci.client_identifier_type_id AND cit.name = 'npid'
    WHERE c.id = #{client_id}
  SQL
  patient.map do |p|
    {
      id: p&.id,
      first_name: p&.first_name,
      last_name: p&.last_name,
      date_of_birth: p&.date_of_birth,
      gender: p&.gender,
      national_patient_id: p&.national_patient_id
    }
  end.first
end

def iblis_tests_for_order(order)
  tests = MlabBase.find_by_sql <<~SQL
    SELECT
      t.id,
      t.uuid as test_uuid,
      ts.name AS test_status,
      t.updated_date AS time_updated,
      t.created_date AS time_created,
      tt.id AS test_type_id,
      tt.name AS test_type_name,
      tt.nlims_code AS test_type_nlims_code,
      s.name AS specimen_name,
      s.nlims_code AS specimen_nlims_code,
      s.preferred_name AS specimen_preferred_name,
      ll.name AS lab_location
    FROM tests t
    INNER JOIN statuses ts ON ts.id = t.status_id
    INNER JOIN test_types tt ON tt.id = t.test_type_id
    INNER JOIN specimen s ON s.id = t.specimen_id
    LEFT JOIN lab_locations ll ON ll.id = t.lab_location_id
    WHERE order_id = #{order.id} and t.voided = 0
  SQL

  return [] if tests.empty?

  # Load all status trails and results for all tests at once (avoid N+1)
  test_ids = tests.map(&:id)
  status_trails_by_test = iblis_test_status_trails_bulk(test_ids)
  results_by_test = iblis_test_results_bulk(test_ids, tests)

  tests.map do |test|
    {
      id: test&.id,
      order_uuid: order&.uuid,
      tracking_number: order&.tracking_number,
      test_uuid: test&.test_uuid,
      test_status: test&.test_status,
      time_updated: test&.time_updated,
      time_created: test&.time_created,
      lab_location: test&.lab_location,
      sample_type: {
        name: test&.specimen_name,
        nlims_code: test&.specimen_nlims_code,
        preferred_name: test&.specimen_preferred_name
      },
      test_type: {
        id: test&.test_type_id,
        name: test&.test_type_name,
        nlims_code: test&.test_type_nlims_code
      },
      status_trail: status_trails_by_test[test.id] || [],
      test_results: results_by_test[test.id] || []
    }
  end
end

def iblis_test_results_bulk(test_ids, tests)
  return {} if test_ids.empty?

  # Build a test_id to test_type_id map
  test_type_map = tests.each_with_object({}) { |t, h| h[t.id] = t.test_type_id }

  test_results = MlabBase.find_by_sql <<~SQL
    SELECT
      tr.test_id,
      tr.id,
      tr.uuid,
      tr.value,
      tr.result_date,
      tr.machine_name AS platform,
      ttim.unit,
      ttim.test_indicator_type AS measure_type,
      ttim.test_types_id,
      ti.name AS test_indicator_name,
      ti.nlims_code AS test_indicator_nlims_code,
      ti.preferred_name AS test_indicator_preferred_name
    FROM test_results tr
    INNER JOIN test_type_indicator_mappings ttim ON ttim.test_indicators_id = tr.test_indicator_id
    INNER JOIN test_indicators ti ON ti.id = tr.test_indicator_id
    WHERE tr.test_id IN (#{test_ids.join(',')}) AND tr.voided = 0
  SQL

  # Group by test_id and filter by correct test_type
  results_by_test = {}
  test_results.each do |test_result|
    test_id = test_result.test_id
    next unless test_type_map[test_id] == test_result.test_types_id

    results_by_test[test_id] ||= []
    results_by_test[test_id] << {
      id: test_result.id,
      uuid: test_result.uuid,
      test_uuid: tests.find { |t| t.id == test_id }&.test_uuid,
      measure: {
        name: test_result.test_indicator_name,
        nlims_code: test_result.test_indicator_nlims_code,
        preferred_name: test_result.test_indicator_preferred_name,
        measure_type: test_result.measure_type
      },
      result: {
        value: test_result.value,
        unit: test_result.unit,
        platform: test_result.platform,
        result_date: test_result.result_date,
        platformserial: ''
      }
    }
  end

  # Remove duplicates based on nlims_code
  results_by_test.transform_values { |results| results.uniq { |r| r[:measure][:nlims_code] } }
end

def iblis_test_status_trails_bulk(test_ids)
  return {} if test_ids.empty?

  status_trails = MlabBase.find_by_sql <<~SQL
    SELECT
      tst.test_id,
      tst.id,
      tst.uuid,
      tst.test_uuid,
      tst.created_date,
      s.name AS status_name,
      tst.creator
    FROM test_statuses tst
    INNER JOIN statuses s ON s.id = tst.status_id
    WHERE tst.test_id IN (#{test_ids.join(',')}) AND tst.voided = 0
  SQL

  trails_by_test = {}
  status_trails.each do |status_trail|
    test_id = status_trail.test_id
    trails_by_test[test_id] ||= []
    trails_by_test[test_id] << {
      id: status_trail.id,
      trail_uuid: status_trail.uuid,
      test_uuid: status_trail.test_uuid,
      status: status_trail.status_name,
      timestamp: status_trail.created_date,
      updated_by: updated_by_for_status_trail(status_trail.creator)
    }
  end

  # Sort each test's trails by timestamp
  trails_by_test.transform_values { |trails| trails.sort_by { |t| t[:timestamp] } }
end

def iblis_order_status_trail_for_order(iblis_order)
  status_trails = MlabBase.find_by_sql <<~SQL
    SELECT
      ost.id,
      ost.uuid,
      ost.order_uuid,
      ost.created_date,
      s.name AS status_name,
      ost.creator
    FROM order_statuses ost
    INNER JOIN statuses s ON s.id = ost.status_id AND ost.order_id = #{iblis_order[:id]}
  SQL
  map_trails = status_trails.map do |status_trail|
    {
      id: status_trail&.id,
      trail_uuid: status_trail&.uuid,
      order_uuid: status_trail&.order_uuid,
      status: status_trail&.status_name&.gsub('-', '_'),
      timestamp: status_trail&.created_date,
      updated_by: updated_by_for_status_trail(status_trail&.creator)
    }
  end
  map_trails.sort_by { |trail| trail[:timestamp] }
end

def updated_by_for_status_trail(status_trail_creator)
  USER_CACHE[status_trail_creator]
end

def sanitize_unit_for_latin1(unit)
  return nil if unit.nil?

  # Convert common scientific notation characters that aren't latin1 compatible
  # μ (Greek mu) -> u
  # ° (degree symbol) is fine in latin1
  unit.to_s
      .gsub('μ', 'u')       # Greek mu to u (microliters μl -> ul)
      .gsub('²', '2')       # Superscript 2
      .gsub('³', '3')       # Superscript 3
      .encode('ISO-8859-1', invalid: :replace, undef: :replace, replace: '?')
rescue Encoding::UndefinedConversionError
  # If conversion still fails, return safe fallback
  unit.to_s.gsub(/[^\x00-\x7F]/, '?')
end

def set_test_to_voided_to_mark_as_synced_to_nlims(iblis_test)
  MlabBase.connection.execute <<~SQL
    UPDATE tests SET voided = 1 WHERE id = #{iblis_test[:id]}
  SQL
end

# NLIMS METHODS
def migrate_iblis_order_to_nlims(iblis_order)
  # Transaction wrapper removed - now handled at batch level for better performance
  nlims_order = Speciman.find_by(tracking_number: iblis_order[:order][:tracking_number])
  if nlims_order.present?
    patient_id = nlims_order.tests.first&.patient_id
    # puts "Order with tracking number #{iblis_order[:order][:tracking_number]} already exists. Updating existing order before migration."
    update_existing_order(nlims_order, iblis_order)
    # puts "Deleting existing order status trail for order with tracking number #{iblis_order[:order][:tracking_number]} before migration."
    delete_and_create_order_status_trail(nlims_order, iblis_order)
    tests_other_than_vl = tests_other_than_vl_for_order(nlims_order)
    # puts "Deleting #{tests_other_than_vl.count} existing tests + test status trails + results other than VL for order with tracking number #{iblis_order[:order][:tracking_number]} before migration."
    delete_test_result_for_tests(tests_other_than_vl)
    delete_test_status_trail_for_tests(tests_other_than_vl)
    delete_tests_for_order_except_vl(tests_other_than_vl)
    iblis_order[:tests].each do |iblis_test|
      is_nlims_test_created = create_nlims_test_for_iblis_test(patient_id, nlims_order, iblis_test)
      unless is_nlims_test_created
        log_failed_test(iblis_order, iblis_test, 'Failed to create test in Nlims', 'Creating Test')
      end
      set_test_to_voided_to_mark_as_synced_to_nlims(iblis_test) if is_nlims_test_created
    end
  else
    # puts "Order with tracking number #{iblis_order[:order][:tracking_number]} does not exist. Creating new order and associated tests."
    patient, nlims_order, error_reason = create_nlims_order(iblis_order)
    if nlims_order.nil? || patient.nil?
      iblis_order[:tests].each do |iblis_test|
        log_failed_test(iblis_order, iblis_test, "Failed to create order or patient in Nlims due to #{error_reason}",
                        'Creating Order')
      end
      raise "Failed to create order or patient for order with tracking number #{iblis_order[:order][:tracking_number]}"
    end

    iblis_order[:tests].each do |iblis_test|
      is_nlims_test_created = create_nlims_test_for_iblis_test(patient.id, nlims_order, iblis_test)
      unless is_nlims_test_created
        log_failed_test(iblis_order, iblis_test, 'Failed to create test in Nlims', 'Creating Test')
      end
      set_test_to_voided_to_mark_as_synced_to_nlims(iblis_test) if is_nlims_test_created
    end
  end
  true
rescue StandardError => e
  puts "Error migrating order with tracking number #{iblis_order[:order][:tracking_number]}: #{e.message}"
  false
end

def update_existing_order(nlims_order, iblis_order)
  specimen_status = SPECIMEN_STATUS_CACHE[iblis_order[:order][:sample_status]]&.id
  specimen_type = SPECIMEN_TYPE_CACHE[iblis_order[:order][:sample_type][:nlims_code]]&.id
  update_parameters = {
    couch_id: iblis_order[:order][:order_uuid],
    date_created: iblis_order[:order][:date_created],
    target_lab: iblis_order[:order][:target_lab],
    sending_facility: iblis_order[:order][:sending_facility],
    district: iblis_order[:order][:district],
    lab_location: iblis_order[:order][:lab_location]
  }
  update_parameters[:specimen_status_id] = specimen_status if specimen_status.present?
  update_parameters[:specimen_type_id] = specimen_type if specimen_type.present?
  nlims_order.update(update_parameters)
end

def delete_and_create_order_status_trail(nlims_order, iblis_order)
  delete_order_status_trail_for_order(nlims_order)

  status_trail_records = iblis_order[:order][:status_trail].map do |status_trail|
    {
      uuid: status_trail[:trail_uuid],
      specimen_id: nlims_order.id,
      order_uuid: status_trail[:order_uuid],
      specimen_status_id: SPECIMEN_STATUS_CACHE[status_trail[:status]]&.id,
      time_updated: status_trail[:timestamp],
      who_updated_id: status_trail[:updated_by][:id],
      who_updated_name: status_trail[:updated_by][:full_name],
      who_updated_phone_number: status_trail[:updated_by][:phone_number],
      created_at: Time.current,
      updated_at: Time.current
    }
  end

  SpecimenStatusTrail.insert_all(status_trail_records) if status_trail_records.any?
end

def tests_other_than_vl_for_order(nlims_order)
  Test.where(specimen_id: nlims_order.id).where.not(test_type_id: VL_TEST_TYPE.id)
end

def delete_tests_for_order_except_vl(tests_other_than_vl_for_order)
  tests_other_than_vl_for_order.destroy_all
end

def delete_test_result_for_tests(tests_other_than_vl_for_order)
  TestResult.where(test_id: tests_other_than_vl_for_order.pluck(:id)).destroy_all
end

def delete_order_status_trail_for_order(nlims_order)
  SpecimenStatusTrail.where(specimen_id: nlims_order.id).destroy_all
end

def delete_test_status_trail_for_tests(tests_other_than_vl_for_order)
  TestStatusTrail.where(test_id: tests_other_than_vl_for_order.pluck(:id)).destroy_all
end

def create_test_status_trail(nlims_test, iblis_test)
  # Bulk insert all test status trails at once
  status_trail_records = iblis_test[:status_trail].map do |status_trail|
    test_status = TEST_STATUS_CACHE[status_trail[:status]]&.id
    {
      uuid: status_trail[:trail_uuid],
      test_id: nlims_test.id,
      test_uuid: status_trail[:test_uuid],
      test_status_id: test_status,
      time_updated: status_trail[:timestamp],
      who_updated_id: status_trail[:updated_by][:id],
      who_updated_name: status_trail[:updated_by][:full_name],
      who_updated_phone_number: status_trail[:updated_by][:phone_number],
      created_at: Time.current,
      updated_at: Time.current
    }
  end

  TestStatusTrail.insert_all(status_trail_records) if status_trail_records.any?
end

def create_test_results(nlims_test, iblis_test)
  # Bulk insert all test results at once
  test_result_records = iblis_test[:test_results].filter_map do |test_result|
    # Use cached measures
    measures = MEASURE_CACHE[test_result[:measure][:nlims_code]]
    next unless measures&.any?

    # Use cached testtype_measures
    testtype_measures = TESTTYPE_MEASURE_CACHE[nlims_test.test_type_id]
    measure = testtype_measures&.find { |tm| measures.map(&:id).include?(tm.measure_id) }&.measure

    unless measure.present?
      Rails.logger.warn "No measure found for nlims_code=#{test_result[:measure][:nlims_code]} test_id=#{nlims_test.id}"
      next
    end

    {
      uuid: test_result[:uuid],
      test_id: nlims_test.id,
      test_uuid: test_result[:test_uuid],
      result: test_result[:result][:value],
      unit: sanitize_unit_for_latin1(test_result[:result][:unit]),
      time_entered: test_result[:result][:result_date],
      device_name: test_result[:result][:platform],
      measure_id: measure.id,
      created_at: Time.current,
      updated_at: Time.current
    }
  end

  TestResult.insert_all(test_result_records) if test_result_records.any?
end

def create_nlims_test_for_iblis_test(patient_id, nlims_order, iblis_test)
  test_status = TEST_STATUS_CACHE[iblis_test[:test_status]]&.id
  test_type = TEST_TYPE_CACHE[iblis_test[:test_type][:nlims_code]]
  return false unless test_type.present?
  return false unless test_status.present?

  create_parameters = {
    uuid: iblis_test[:test_uuid],
    specimen_id: nlims_order.id,
    order_uuid: iblis_test[:order_uuid],
    test_type_id: test_type.id,
    test_status_id: test_status,
    time_created: iblis_test[:time_created],
    patient_id: patient_id
  }
  nlims_test = Test.create!(create_parameters)
  create_test_status_trail(nlims_test, iblis_test)
  create_test_results(nlims_test, iblis_test)
  true
end

def create_patient(params)
  npid = params[:national_patient_id]
  name = "#{params[:first_name]} #{params[:last_name]}"
  patient_obj = Patient.find_by(patient_number: npid)
  if patient_obj.present?
    patient_obj.dob = params[:date_of_birth]
    patient_obj.update!(name:)
    patient_obj.save!
  else
    patient_obj = Patient.create!(
      patient_number: npid,
      name:,
      email: params[:email],
      dob: params[:date_of_birth],
      gender: params[:gender],
      phone_number: params[:phone_number],
      address: params[:address],
      external_patient_number: ''
    )
  end
  patient_obj
end

def create_nlims_order(iblis_order)
  patient = create_patient(iblis_order[:patient])
  params = iblis_order[:order]
  order_ward = Ward.get_ward_id(NameMapping.actual_name_of(params[:order_location]))
  specimen_status = SPECIMEN_STATUS_CACHE[iblis_order[:order][:sample_status]]&.id
  specimen_type = SPECIMEN_TYPE_CACHE[iblis_order[:order][:sample_type][:nlims_code]]&.id
  return [nil, nil, :missing_ward]   unless order_ward.present?
  return [nil, nil, :missing_status] unless specimen_status.present?
  return [nil, nil, :missing_type]   unless specimen_type.present?

  create_parameters = {
    couch_id: params[:order_uuid],
    tracking_number: params[:tracking_number],
    specimen_type_id: specimen_type,
    specimen_status_id: specimen_status,
    ward_id: order_ward,
    date_created: params[:date_created],
    priority: params[:priority],
    drawn_by_id: params[:drawn_by][:id],
    drawn_by_name: params[:drawn_by][:name],
    drawn_by_phone_number: params[:drawn_by][:phone_number],
    target_lab: params[:target_lab],
    sending_facility: params[:sending_facility],
    district: params[:district],
    requested_by: params[:requested_by],
    art_start_date: params[:art_start_date],
    arv_number: params[:arv_number] || 'N/A',
    art_regimen: params[:art_regimen] || 'N/A',
    clinical_history: params[:clinical_history],
    lab_location: params[:lab_location],
    source_system: params[:source_system]
  }
  order = Speciman.create!(create_parameters)
  [patient, order]
end

def format_duration(seconds)
  hours = (seconds / 3600).to_i
  minutes = ((seconds % 3600) / 60).to_i
  secs = (seconds % 60).to_i

  if hours > 0
    "#{hours}h #{minutes}m #{secs}s"
  elsif minutes > 0
    "#{minutes}m #{secs}s"
  else
    "#{secs}s"
  end
end

def log_failed_test(iblis_order, iblis_test, reason, stage)
  puts "Failed to migrate order with tracking number #{iblis_order[:order][:tracking_number]}"
  MlabSyncFailure.create!(
    tracking_number: iblis_order[:order][:tracking_number],
    mlab_test_id: iblis_test[:id],
    test_type_nlims_code: iblis_test[:test_type][:nlims_code],
    site_name: iblis_order[:order][:sending_facility],
    failure_reason: reason,
    failure_stage: stage,
    payload_snapshot: iblis_test.to_json,
    resolved: false
  )
end

def main(prep: false, start_datetime: nil, end_datetime: nil, skip_count: false)
  MlabSyncFailure.delete_all if prep
  # Get orders that have tests where voided = 0 to ensure we only migrate orders that haven't been marked as migrated before. This also allows us to reprocess orders that failed migration in previous runs by not marking them as voided.
  puts 'Fetching orders to migrate...'

  # Build base query
  orders_relation = MlabBase.joins('INNER JOIN tests t ON t.order_id = orders.id').where('t.voided = 0')

  # Apply datetime filters if provided
  if start_datetime.present?
    orders_relation = orders_relation.where('orders.created_date >= ?', start_datetime)
    puts "Filtering orders from: #{start_datetime.strftime('%Y-%m-%d %H:%M:%S')}"
  end

  if end_datetime.present?
    orders_relation = orders_relation.where('orders.created_date <= ?', end_datetime)
    puts "Filtering orders until: #{end_datetime.strftime('%Y-%m-%d %H:%M:%S')}"
  end

  orders_relation = orders_relation.distinct

  # Count total orders (can be slow on large datasets)
  total_orders = if skip_count
                   puts 'Skipping count for faster startup...'
                   nil
                 else
                   puts 'Counting total orders (this may take a moment for large date ranges)...'
                   count_start_time = Time.now
                   count_result = orders_relation.count
                   count_duration = Time.now - count_start_time
                   puts "Count completed in #{count_duration.round(2)} seconds"
                   count_result
                 end

  puts '=' * 80
  datetime_range_info = if [start_datetime, end_datetime].compact.any?
                          start_str = start_datetime ? start_datetime.strftime('%Y-%m-%d %H:%M:%S') : 'beginning'
                          end_str = end_datetime ? end_datetime.strftime('%Y-%m-%d %H:%M:%S') : 'now'
                          " (DateTime Range: #{start_str} to #{end_str})"
                        else
                          ''
                        end
  order_count_msg = total_orders ? "#{total_orders} orders" : 'orders (count skipped)'
  puts "Starting migration of #{order_count_msg} in batches of 500#{datetime_range_info}"
  puts '=' * 80
  puts ''

  # Track timing
  migration_start_time = Time.now
  last_checkpoint_time = migration_start_time
  puts "Migration started at: #{migration_start_time.strftime('%Y-%m-%d %H:%M:%S')}"
  puts ''

  processed_count = 0
  success_count = 0
  failure_count = 0
  orders_in_transaction = 0

  orders_relation.find_in_batches(batch_size: 2000) do |batch|
    batch.each do |order|
      # Format order created date early for use in all log messages
      order_created_date = order.created_date ? order.created_date.strftime('%Y-%m-%d %H:%M:%S') : 'unknown date'

      processed_count += 1
      progress_percentage = total_orders ? ((processed_count.to_f / total_orders) * 100).round(2) : nil

      show_detailed_output = (processed_count % 10 == 0) || (total_orders && processed_count == total_orders)

      if show_detailed_output
        current_time = Time.now
        elapsed_since_last = current_time - last_checkpoint_time
        total_elapsed = current_time - migration_start_time

        puts '=' * 80
        if total_orders
          puts "Progress: #{progress_percentage}% (#{processed_count}/#{total_orders})"
        else
          puts "Progress: #{processed_count} orders processed"
        end
        puts "Migrating order with tracking number #{order.tracking_number}"
        puts "Time since last checkpoint: #{elapsed_since_last.round(2)}s | Total elapsed: #{format_duration(total_elapsed)}"
        puts '-' * 80

        last_checkpoint_time = current_time
      end

      # Start new transaction batch if needed
      ActiveRecord::Base.connection.begin_db_transaction if orders_in_transaction == 0

      iblis_order_data = iblis_order(order)
      result = migrate_iblis_order_to_nlims(iblis_order_data)

      if result
        success_count += 1
        orders_in_transaction += 1
        if show_detailed_output
          puts "✓ Successfully migrated order #{order.tracking_number} (created on #{order_created_date})"
        end
      else
        failure_count += 1
        puts "✗ Failed to migrate order #{order.tracking_number} (created on #{order_created_date})"
      end

      # Commit transaction batch when we reach the batch size
      if orders_in_transaction >= TRANSACTION_BATCH_SIZE
        ActiveRecord::Base.connection.commit_db_transaction
        orders_in_transaction = 0
      end

      if show_detailed_output
        puts "Success: #{success_count} | Failures: #{failure_count}"
        puts '=' * 80
        puts "\n"
      end
    rescue StandardError => e
      failure_count += 1
      # Rollback current transaction batch on error
      if orders_in_transaction > 0
        ActiveRecord::Base.connection.rollback_db_transaction
        orders_in_transaction = 0
      end
      puts "✗ Exception while processing order #{order.tracking_number} (created on #{order_created_date}): #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end

    # Commit any remaining orders in the transaction batch at end of batch
    if orders_in_transaction > 0
      ActiveRecord::Base.connection.commit_db_transaction
      orders_in_transaction = 0
    end

    # Print batch completion summary
    puts ''
    puts '=' * 80
    if total_orders
      puts "Batch completed. Progress: #{((processed_count.to_f / total_orders) * 100).round(2)}%"
      puts "Total Processed: #{processed_count}/#{total_orders}"
    else
      puts "Batch completed. Total Processed: #{processed_count}"
    end
    puts "Successful: #{success_count} | Failed: #{failure_count}"
    puts '=' * 80
    puts "\n\n"
  end

  # Final summary
  migration_end_time = Time.now
  total_duration = migration_end_time - migration_start_time
  processing_rate = processed_count > 0 ? (processed_count.to_f / total_duration).round(2) : 0

  puts ''
  puts '=' * 80
  puts 'MIGRATION COMPLETED'
  puts '=' * 80
  puts "Started at:  #{migration_start_time.strftime('%Y-%m-%d %H:%M:%S')}"
  puts "Completed at: #{migration_end_time.strftime('%Y-%m-%d %H:%M:%S')}"
  puts "Total Duration: #{format_duration(total_duration)}"
  puts "Processing Rate: #{processing_rate} orders/second"
  puts '-' * 80
  if total_orders
    puts "Total Orders: #{total_orders}"
    puts "Successfully Migrated: #{success_count}"
    puts "Failed: #{failure_count}"
    puts "Success Rate: #{((success_count.to_f / total_orders) * 100).round(2)}%"
  else
    puts "Total Orders Processed: #{processed_count}"
    puts "Successfully Migrated: #{success_count}"
    puts "Failed: #{failure_count}"
    puts "Success Rate: #{processed_count > 0 ? ((success_count.to_f / processed_count) * 100).round(2) : 0}%"
  end
  puts '=' * 80
end

# Prompt user for options
puts ''
puts '=' * 80
puts 'MIGRATION CONFIGURATION'
puts '=' * 80
puts ''

print 'Clear mlab sync failure table before starting? (y/N): '
user_input = gets.chomp.downcase
prep_option = %w[y yes].include?(user_input)

puts ''
puts 'Start DateTime Filter (optional)'
puts 'Format: YYYY-MM-DD HH:MM:SS or YYYY-MM-DD (defaults to 00:00:00)'
print 'Leave blank to process from beginning: '
start_datetime_input = gets.chomp.strip
start_datetime = if start_datetime_input.empty?
                   nil
                 else
                   begin
                     # Check if input includes time component (contains colon)
                     if start_datetime_input.include?(':')
                       Time.parse(start_datetime_input)
                     else
                       # Date only - default to beginning of day
                       Date.parse(start_datetime_input).to_time
                     end
                   rescue ArgumentError
                     puts 'Invalid datetime format. Ignoring start filter.'
                     nil
                   end
                 end

puts ''
puts 'End DateTime Filter (optional)'
puts 'Format: YYYY-MM-DD HH:MM:SS or YYYY-MM-DD (defaults to 23:59:59)'
print 'Leave blank to process until now: '
end_datetime_input = gets.chomp.strip
end_datetime = if end_datetime_input.empty?
                 nil
               else
                 begin
                   # Check if input includes time component (contains colon)
                   if end_datetime_input.include?(':')
                     Time.parse(end_datetime_input)
                   else
                     # Date only - default to end of day (23:59:59)
                     Date.parse(end_datetime_input).end_of_day
                   end
                 rescue ArgumentError
                   puts 'Invalid datetime format. Ignoring end filter.'
                   nil
                 end
               end

puts ''
print 'Skip counting total orders for faster startup? (y/N): '
skip_count_input = gets.chomp.downcase
skip_count_option = %w[y yes].include?(skip_count_input)

puts '=' * 80
puts ''

main(prep: prep_option, start_datetime: start_datetime, end_datetime: end_datetime, skip_count: skip_count_option)
