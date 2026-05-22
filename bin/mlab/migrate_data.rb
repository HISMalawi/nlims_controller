# frozen_string_literal: true

orders = MlabBase.all
VL_TEST_TYPE = TestType.find_by(nlims_code: 'NLIMS_TT_0071_MWI')

orders.each do |order|
  is_already_available = Speciman.find_by(tracking_number: order.tracking_number)
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
      target_lab: iblis_global_facility[:name],
      sending_facility: iblis_global_facility[:name],
      district: iblis_global_facility[:district],
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
    tests: tests,
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
    WHERE order_id = #{order.id}
  SQL

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
      status_trail: iblis_test_status_trail_for_tests(test),
      test_results: iblis_test_results_for_tests(test)
    }
  end
end

def iblis_test_results_for_tests(iblis_test)
  test_results = MlabBase.find_by_sql <<~SQL
    SELECT
      tr.id,
      tr.uuid,
      tr.value,
      tr.result_date,
      tr.machine_name AS platform,
      ttim.unit,
      ttim.test_indicator_type AS measure_type,
      ti.name AS test_indicator_name,
      ti.nlims_code AS test_indicator_nlims_code,
      ti.preferred_name AS test_indicator_preferred_name
    FROM test_results tr
    INNER JOIN test_type_indicator_mappings ttim ON ttim.test_indicators_id = tr.test_indicator_id AND
      ttim.test_types_id = #{iblis_test[:test_type_id]}
    INNER JOIN test_indicators ti ON ti.id = tr.test_indicator_id
    WHERE tr.test_id = #{iblis_test[:id]}
  SQL

  test_results.map do |test_result|
    {
      id: test_result.id,
      uuid: test_result.uuid,
      test_uuid: iblis_test[:test_uuid],
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
end

def iblis_test_status_trail_for_tests(iblis_test)
  status_trails = MlabBase.find_by_sql <<~SQL
    SELECT
      tst.id,
      tst.uuid,
      tst.test_uuid,
      tst.created_date,
      s.name AS status_name,
      tst.creator
    FROM test_statuses tst
    INNER JOIN statuses s ON s.id = tst.status_id
    WHERE tst.test_id = #{iblis_test[:id]}
  SQL
  map_trails = status_trails.map do |status_trail|
    {
      id: status_trail.id,
      trail_uuid: status_trail.uuid,
      test_uuid: status_trail.test_uuid,
      status: status_trail.status_name,
      timestamp: status_trail.created_date,
      updated_by: updated_by_for_status_trail(status_trail[:creator])
    }
  end
  map_trails.sort_by { |trail| trail[:timestamp] }
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
  user = MlabBase.find_by_sql <<~SQL
    SELECT
      u.id,
      p.first_name,
      p.last_name
    FROM users u
    INNER JOIN people p ON p.id = u.person_id AND u.id = #{status_trail_creator}
  SQL
  return { id: nil, first_name: 'Unknown', last_name: 'User', phone_number: nil, full_name: 'Unknown User' } if user.empty?

  {
    id: user.first&.id,
    first_name: user.first&.first_name,
    last_name: user.first&.last_name,
    phone_number: nil,
    full_name: "#{user.first&.first_name} #{user.first&.last_name}"
  }
end

# NLIMS METHODS
def migrate_iblis_order_to_nlims(iblis_order)
  nlims_order = Speciman.find_by(tracking_number: iblis_order[:order][:tracking_number])
  if nlims_order.present?
    puts "Order with tracking number #{iblis_order[:order][:tracking_number]} already exists. Updating existing order before migration."
    update_existing_order(nlims_order, iblis_order)
    puts "Deleting existing order status trail for order with tracking number #{iblis_order[:order][:tracking_number]} before migration."
    delete_and_create_order_status_trail(nlims_order, iblis_order)
    tests_other_than_vl = tests_other_than_vl_for_order(nlims_order)
    if tests_other_than_vl.any?
      puts "Deleting #{tests_other_than_vl.count} existing tests + test status trails + results other than VL for order with tracking number #{iblis_order[:order][:tracking_number]} before migration."
      delete_test_result_for_tests(tests_other_than_vl)
      delete_test_status_trail_for_tests(tests_other_than_vl)
      delete_tests_for_order_except_vl(tests_other_than_vl)
    end
  end
end

def update_existing_order(nlims_order, iblis_order)
  specimen_status = SpecimenStatus.find_by(name: iblis_order[:order][:sample_status])&.id
  update_parameters = {
    couch_id: iblis_order[:order][:order_uuid],
    date_created: iblis_order[:order][:date_created],
    target_lab: iblis_order[:order][:target_lab],
    sending_facility: iblis_order[:order][:sending_facility],
    district: iblis_order[:order][:district]
  }
  update_parameters[:specimen_status_id] = specimen_status if specimen_status.present?
  puts "Updating order with tracking number #{iblis_order[:order][:tracking_number]} with parameters: #{update_parameters}"
  nlims_order.update(update_parameters)
end

def delete_and_create_order_status_trail(nlims_order, iblis_order)
  delete_order_status_trail_for_order(nlims_order)
  iblis_order[:order][:status_trail].each do |status_trail|
    specimen_status = SpecimenStatus.find_by(name: status_trail[:status])&.id
    create_parameters = {
      uuid: status_trail[:trail_uuid],
      specimen_id: nlims_order.id,
      order_uuid: status_trail[:order_uuid],
      specimen_status_id: specimen_status,
      time_updated: status_trail[:timestamp],
      who_updated_id: status_trail[:updated_by][:id],
      who_updated_name: status_trail[:updated_by][:full_name],
      who_updated_phone_number: status_trail[:updated_by][:phone_number]
    }
    puts "Creating order status trail for order with tracking number #{iblis_order[:order][:tracking_number]} with parameters: #{create_parameters}"
    SpecimenStatusTrail.create!(create_parameters)
  end
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
  iblis_test[:status_trail].each do |status_trail|
    test_status = TestStatus.find_by(name: status_trail[:status])&.id
    create_parameters = {
      uuid: status_trail[:trail_uuid],
      test_id: nlims_test.id,
      test_uuid: status_trail[:test_uuid],
      test_status_id: test_status,
      time_updated: status_trail[:timestamp],
      who_updated_id: status_trail[:updated_by][:id],
      who_updated_name: status_trail[:updated_by][:full_name],
      who_updated_phone_number: status_trail[:updated_by][:phone_number]
    }
    puts "Creating test status trail for test with uuid #{nlims_test.uuid} with parameters: #{create_parameters}"
    TestStatusTrail.create!(create_parameters)
  end
end

def create_test_results(nlims_test, iblis_test)
  iblis_test[:test_results].each do |test_result|
    create_parameters = {
      uuid: test_result[:uuid],
      test_id: nlims_test.id,
      test_uuid: test_result[:test_uuid],
      value: test_result[:result][:value],
      unit: test_result[:result][:unit],
      platform: test_result[:result][:platform],
      result_date: test_result[:result][:result_date],
      platformserial: test_result[:result][:platformserial],
      measure_name: test_result[:measure][:name],
      measure_nlims_code: test_result[:measure][:nlims_code],
      measure_preferred_name: test_result[:measure][:preferred_name],
      measure_type: test_result[:measure][:measure_type]
    }
    puts "Creating test result for test with uuid #{nlims_test.uuid} with parameters: #{create_parameters}"
    TestResult.create!(create_parameters)
  end
end
