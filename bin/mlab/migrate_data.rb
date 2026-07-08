# frozen_string_literal: true

VL_TEST_TYPE = TestType.find_by(nlims_code: 'NLIMS_TT_0071_MWI')
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

  results = test_results.map do |test_result|
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
  results.uniq { |result| result[:measure][:nlims_code] }
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
  if user.empty?
    return { id: nil, first_name: 'Unknown', last_name: 'User', phone_number: nil,
             full_name: 'Unknown User' }
  end

  {
    id: user.first&.id,
    first_name: user.first&.first_name,
    last_name: user.first&.last_name,
    phone_number: nil,
    full_name: "#{user.first&.first_name} #{user.first&.last_name}"
  }
end

def set_test_to_voided_to_mark_as_synced_to_nlims(iblis_test)
  MlabBase.connection.execute <<~SQL
    UPDATE tests SET voided = 1 WHERE id = #{iblis_test[:id]}
  SQL
end

# NLIMS METHODS
def migrate_iblis_order_to_nlims(iblis_order)
  ActiveRecord::Base.transaction do
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
      patient, nlims_order = create_nlims_order(iblis_order)
      if nlims_order.nil? || patient.nil?
        iblis_order[:tests].each do |iblis_test|
          log_failed_test(iblis_order, iblis_test, 'Failed to create order or patient in Nlims', 'Creating Order')
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
    puts "Successfully migrated order with tracking number #{iblis_order[:order][:tracking_number]}"
    return true
  rescue StandardError => e
    puts "Error migrating order with tracking number #{iblis_order[:order][:tracking_number]}: #{e.message}"
    return false
  end
end

def update_existing_order(nlims_order, iblis_order)
  specimen_status = SpecimenStatus.find_by(name: iblis_order[:order][:sample_status])&.id
  specimen_type = SpecimenType.find_by(nlims_code: iblis_order[:order][:sample_type][:nlims_code])&.id
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
  # puts "Updating order with tracking number #{iblis_order[:order][:tracking_number]} with parameters: #{update_parameters}"
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
    # puts "Creating order status trail for order with tracking number #{iblis_order[:order][:tracking_number]} with parameters: #{create_parameters}"
    SpecimenStatusTrail.create!(create_parameters)
  end
end

def tests_other_than_vl_for_order(nlims_order)
  Test.where(specimen_id: nlims_order.id).where.not(test_type_id: VL_TEST_TYPE.id)
end

def delete_tests_for_order_except_vl(tests_other_than_vl_for_order)
  tests_other_than_vl_for_order.delete_all
end

def delete_test_result_for_tests(tests_other_than_vl_for_order)
  TestResult.where(test_id: tests_other_than_vl_for_order.pluck(:id)).delete_all
end

def delete_order_status_trail_for_order(nlims_order)
  SpecimenStatusTrail.where(specimen_id: nlims_order.id).delete_all
end

def delete_test_status_trail_for_tests(tests_other_than_vl_for_order)
  TestStatusTrail.where(test_id: tests_other_than_vl_for_order.pluck(:id)).delete_all
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
    # puts "Creating test status trail for test with uuid #{nlims_test.uuid} with parameters: #{create_parameters}"
    TestStatusTrail.create!(create_parameters)
  end
end

def create_test_results(nlims_test, iblis_test)
  iblis_test[:test_results].each do |test_result|
    create_parameters = {
      uuid: test_result[:uuid],
      test_id: nlims_test.id,
      test_uuid: test_result[:test_uuid],
      result: test_result[:result][:value],
      unit: test_result[:result][:unit],
      time_entered: test_result[:result][:result_date],
      device_name: test_result[:result][:platform]
    }
    measures = Measure.where(name: test_result[:measure][:name], nlims_code: test_result[:measure][:nlims_code])
    measures ||= Measure.where(nlims_code: test_result[:measure][:nlims_code])
    measure = TesttypeMeasure.where(test_type_id: nlims_test.test_type_id, measure_id: measures&.ids)&.first&.measure
    next unless measure.present?

    create_parameters[:measure_id] = measure.id
    # puts "Creating test result for test with uuid #{nlims_test.uuid} with parameters: #{create_parameters}"
    TestResult.create!(create_parameters)
  end
end

def create_nlims_test_for_iblis_test(patient_id, nlims_order, iblis_test)
  test_status = TestStatus.find_by(name: iblis_test[:test_status])&.id
  test_type = TestType.find_by(nlims_code: iblis_test[:test_type][:nlims_code])
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
  # puts "Creating test for order with tracking number #{iblis_test[:tracking_number]} with parameters: #{create_parameters}"
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
  specimen_status = SpecimenStatus.find_by(name: iblis_order[:order][:sample_status])&.id
  specimen_type = SpecimenType.find_by(nlims_code: iblis_order[:order][:sample_type][:nlims_code])&.id
  return [nil, nil] unless order_ward.present? && specimen_status.present? && specimen_type.present?

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
  # puts "Creating order with tracking number #{iblis_order[:order][:tracking_number]} with parameters: #{create_parameters}"
  order = Speciman.create!(create_parameters)
  [patient, order]
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

def main(prep: false)
  MlabSyncFailure.delete_all if prep
  # Get orders that have tests where voided = 0 to ensure we only migrate orders that haven't been marked as migrated before. This also allows us to reprocess orders that failed migration in previous runs by not marking them as voided.
  puts 'Fetching orders to migrate...'
  orders_query = MlabBase.find_by_sql <<~SQL
    SELECT DISTINCT o.*
    FROM orders o
    INNER JOIN tests t ON t.order_id = o.id
    WHERE t.voided = 0
  SQL
  total_orders = orders_query.count

  puts '=' * 80
  puts "Starting migration of #{total_orders} orders in batches of 10,000"
  puts '=' * 80
  puts ''

  processed_count = 0
  success_count = 0
  failure_count = 0

  orders_query.each_slice(10_000) do |batch|
    batch.each do |order|
      processed_count += 1
      progress_percentage = ((processed_count.to_f / total_orders) * 100).round(2)

      puts '=' * 80
      puts "Progress: #{progress_percentage}% (#{processed_count}/#{total_orders})"
      puts "Migrating order with tracking number #{order.tracking_number}"
      puts '-' * 80

      iblis_order_data = iblis_order(order)
      result = migrate_iblis_order_to_nlims(iblis_order_data)

      if result
        success_count += 1
        puts "✓ Successfully migrated order #{order.tracking_number}"
      else
        failure_count += 1
        puts "✗ Failed to migrate order #{order.tracking_number}"
      end

      puts "Success: #{success_count} | Failures: #{failure_count}"
      puts '=' * 80
      puts "\n"
    rescue StandardError => e
      failure_count += 1
      puts "✗ Exception while processing order #{order.tracking_number}: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end

    # Print batch completion summary
    puts ''
    puts '=' * 80
    puts "Batch completed. Progress: #{((processed_count.to_f / total_orders) * 100).round(2)}%"
    puts "Total Processed: #{processed_count}/#{total_orders}"
    puts "Successful: #{success_count} | Failed: #{failure_count}"
    puts '=' * 80
    puts "\n\n"
  end

  # Final summary
  puts ''
  puts '=' * 80
  puts 'MIGRATION COMPLETED'
  puts '=' * 80
  puts "Total Orders: #{total_orders}"
  puts "Successfully Migrated: #{success_count}"
  puts "Failed: #{failure_count}"
  puts "Success Rate: #{total_orders > 0 ? ((success_count.to_f / total_orders) * 100).round(2) : 0}%"
  puts '=' * 80
end

# Prompt user for prep option
puts ''
puts '=' * 80
print 'Clear mlab sync failure table before starting? (y/N): '
user_input = gets.chomp.downcase
prep_option = %w[y yes].include?(user_input)
puts '=' * 80
puts ''

main(prep: prep_option)
