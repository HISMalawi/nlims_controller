# frozen_string_literal: true

#  OrderService module
module OrderService
  def self.create_order(params, tracking_number)
    ActiveRecord::Base.transaction do
      params[:tests].each do |tst|
        tst = NameMapping.actual_name_of(tst)
        tst =  check_test_name(tst)
        return [false, 'test name not available in nlims'] if tst == false
      end
      params[:sample_type] = NameMapping.actual_name_of(params[:sample_type])
      spc = SpecimenType.find_by(name: params[:sample_type])
      return [false, 'specimen type not available in nlims'] if spc.blank?

      spc = SpecimenStatus.find_by(name: params[:sample_status])
      return [false, 'specimen status not available in nlims'] if spc.blank?

      npid = params[:national_patient_id]
      patient_obj = Patient.where(patient_number: npid)
      patient_obj = patient_obj.first unless patient_obj.blank?
      if patient_obj.blank?
        patient_obj = patient_obj.create(
          patient_number: npid,
          name: "#{params[:first_name]} #{params[:last_name]}",
          email: '',
          dob: params[:date_of_birth],
          gender: params[:gender],
          phone_number: params[:phone_number],
          address: '',
          external_patient_number: ''
        )
      else
        patient_obj.dob = params[:date_of_birth]
        patient_obj.update(name: "#{params[:first_name]} #{params[:last_name]}")
        patient_obj.save
      end
      time = params[:date_sample_drawn].blank? ? Date.today : params[:date_sample_drawn]

      sample_type_id = SpecimenType.get_specimen_type_id(params[:sample_type])
      params[:sample_status] = 'specimen_accepted' if params[:sample_status] == 'specimen-accepted'
      params[:sample_status] = 'specimen_accepted' if params[:status] == 'specimen-accepted'
      sample_status_id = SpecimenStatus.get_specimen_status_id(params[:sample_status])
      order_ward = Ward.get_ward_id(NameMapping.actual_name_of(params[:order_location]))
      sp_obj = Speciman.create(
        tracking_number:,
        specimen_type_id: sample_type_id,
        specimen_status_id: sample_status_id,
        couch_id: SecureRandom.uuid,
        ward_id: order_ward,
        priority: params[:sample_priority],
        drawn_by_id: params[:who_order_test_id],
        drawn_by_name: "#{params[:who_order_test_first_name]} #{params[:who_order_test_last_name]}",
        drawn_by_phone_number: params[:who_order_test_phone_number],
        target_lab: params[:target_lab],
        art_start_date: params[:art_start_date],
        sending_facility: params[:health_facility_name],
        requested_by: params[:requesting_clinician],
        district: params[:district],
        date_created: time,
        arv_number: params[:arv_number] || 'N/A',
        art_regimen: params[:art_regimen] || 'N/A'
      )
      res = Visit.create(
        patient_id: npid,
        visit_type_id: '',
        ward_id: order_ward
      )
      params[:tests].each do |tst|
        tst = NameMapping.actual_name_of(tst)
        tst = check_test_name(tst)
        status = check_test(tst)
        if status == false
          rst = TestType.get_test_type_id(tst)
          rst2 = TestStatus.get_test_status_id('drawn')
          Test.create(
            specimen_id: sp_obj.id,
            test_type_id: rst,
            patient_id: patient_obj.id,
            created_by: "#{params[:who_order_test_first_name]} #{params[:who_order_test_last_name]}",
            panel_id: '',
            time_created: time,
            test_status_id: rst2
          )
        else
          pa_id = PanelType.where(name: tst).first
          res = TestType.find_by_sql("SELECT test_types.id FROM test_types INNER JOIN panels
                                                            ON panels.test_type_id = test_types.id
                                                            INNER JOIN panel_types ON panel_types.id = panels.panel_type_id
                                                            WHERE panel_types.id ='#{pa_id.id}'")
          res.each do |tt|
            rst2 = TestStatus.get_test_status_id('drawn')
            Test.create(
              specimen_id: sp_obj.id,
              test_type_id: tt.id,
              patient_id: patient_obj.id,
              created_by: "#{params[:who_order_test_first_name]} #{params[:who_order_test_last_name]}",
              panel_id: '',
              time_created: time,
              test_status_id: rst2
            )
          end
        end
      end
    end

    [true, tracking_number]
  end

  def self.check_order(tracking_number)
    order = Speciman.where(tracking_number:).first
    if order
      true
    else
      false
    end
  end

  def self.query_order_by_tracking_number_v2(tracking_number, test_name)
    test_name = NameMapping.actual_name_of(test_name)
    res = Speciman.find_by_sql("SELECT specimen_types.name AS sample_type, specimen_statuses.name AS specimen_status,
                        wards.name AS order_location, specimen.date_created AS date_created, specimen.priority AS priority,
                        specimen.drawn_by_id AS drawer_id, specimen.drawn_by_name AS drawer_name,
                        specimen.drawn_by_phone_number AS drawe_number, specimen.target_lab AS target_lab,
                        specimen.sending_facility AS health_facility, specimen.requested_by AS requested_by,
                        specimen.date_created AS date_drawn,
                        patients.patient_number AS pat_id, patients.name AS pat_name,
                        patients.dob AS dob, patients.gender AS sex,
                        art_regimen AS art_regi, arv_number AS arv_number,
                        art_start_date AS art_start_date
                        FROM specimen INNER JOIN specimen_statuses ON specimen_statuses.id = specimen.specimen_status_id
                        LEFT JOIN specimen_types ON specimen_types.id = specimen.specimen_type_id
                        INNER JOIN tests ON tests.specimen_id = specimen.id
                        INNER JOIN patients ON patients.id = tests.patient_id
                        LEFT JOIN wards ON specimen.ward_id = wards.id
                        WHERE specimen.tracking_number ='#{tracking_number}'")
    tsts = {}
    result_status = false
    result_measures = {}
    result_val = {}
    if !res.empty?
      site_code_number = get_site_code_number(tracking_number)
      res = res[0]
      tst = Test.find_by_sql("SELECT test_types.name AS test_name, test_statuses.name AS test_status,
                              tests.id  AS test_id
                              FROM tests
                              INNER JOIN specimen ON specimen.id = tests.specimen_id
                              INNER JOIN test_types ON test_types.id = tests.test_type_id
                              INNER JOIN test_statuses ON test_statuses.id = tests.test_status_id
                              WHERE specimen.tracking_number ='#{tracking_number}' AND test_types.name='#{test_name}'")
      unless tst.empty?
        tst.each do |t|
          updater_trailer = {}
          trail = TestStatusTrail.find_by_sql("SELECT test_statuses.name AS test_status,test_status_trails.time_updated,test_status_trails.who_updated_name,
							test_status_trails.who_updated_id FROM test_status_trails
							 INNER JOIN test_statuses ON test_status_trails.test_status_id = test_statuses.id
							WHERE test_id='#{t.test_id}' order by test_status_trails.id desc limit 1")
          unless trail.blank?
            updater_trailer = {
              "updater_name": trail[0]['who_updated_name'],
              "updater_id": trail[0]['who_updated_id'],
              "time_updated": trail[0]['time_updated'],
              "status": trail[0]['test_status']
            }
          end
          tsts[t.test_name] = { "status": t.test_status, "update_details": updater_trailer }
          result_got = TestResult.find_by_sql("SELECT * FROM test_results WHERE test_id='#{t.test_id}'")
          next if result_got.blank?

          result_got.each do |reslt|
            result_value = reslt['result']
            result_measure = Measure.find_by(id: reslt['measure_id'])['name']
            result_measures[result_measure] =
              { 'result': result_value, 'result_date': reslt['time_entered'] }
          end
          result_val[t.test_name] = result_measures
          result_measures = {}
          result_status = true
        end
      end
      arv_number = ''
      arv_number = res.arv_number.split('-') unless res.arv_number.blank?
      arv_number = arv_number[arv_number.length - 1] unless arv_number.blank?
      if result_status == true
        {
          gen_details: {
            sample_type: res.sample_type,
            specimen_status: res.specimen_status,
            order_location: res.order_location,
            date_created: res.date_created,
            priority: res.priority,
            art_regimen: res.art_regi,
            arv_number:,
            site_code_number:,
            art_start_date: res.art_start_date,
            sample_created_by: {
              id: res.drawe_number,
              name: res.drawer_name,
              phone: res.drawe_number
            },
            patient: {
              id: res.pat_id,
              name: res.pat_name,
              gender: res.sex,
              dob: res.dob
            },
            receiving_lab: res.target_lab,
            sending_lab: res.health_facility,
            sending_lab_code: site_code_number,
            requested_by: res.requested_by,
            tracking_number:,
            results: result_val
          },
          tests: tsts

        }
      else
        {
          gen_details: {
            sample_type: res.sample_type,
            specimen_status: res.specimen_status,
            order_location: res.order_location,
            date_created: res.date_created,
            priority: res.priority,
            art_regimen: res.art_regi,
            arv_number:,
            site_code_number:,
            art_start_date: res.art_start_date,
            sample_created_by: {
              id: res.drawe_number,
              name: res.drawer_name,
              phone: res.drawe_number
            },
            patient: {
              id: res.pat_id,
              name: res.pat_name,
              gender: res.sex,
              dob: res.dob
            },
            receiving_lab: res.target_lab,
            sending_lab: res.health_facility,
            sending_lab_code: site_code_number,
            requested_by: res.requested_by,
            tracking_number:
          },
          tests: tsts
        }
      end
    else
      false
    end
  end

  def self.get_site_code_number(site_code_alpha)
    site_code_number = ''
    return site_code_number if site_code_alpha.blank?

    if site_code_alpha[0..0].upcase == 'L' || site_code_alpha[0..0] == '0'
      site_code_number = site_code_number_by_facility(site_code_alpha)
    else
      match = site_code_alpha[/^[A-Za-z]+/]
      code_alpha = match && match.upcase.start_with?('X') ? match[1..-1] : match
      site_code_number = Site.find_by(site_code: code_alpha)&.site_code_number
      site_code_number ||= site_code_number_by_facility(site_code_alpha)
      site_code_number = site_code_number_by_facility(site_code_alpha) if code_alpha == 'KCH'
    end
    site_code_number
  end

  def self.site_code_number_by_facility(tracking_number)
    sending_facility = Speciman.find_by(tracking_number:)&.sending_facility
    Site.find_by(name: sending_facility)&.site_code_number || ''
  end

  def self.check_test_name(test_name)
    tst = TestType.find_by_sql("SELECT name AS tst_name FROM test_types WHERE name ='#{test_name}' LIMIT 1")
    return tst[0].tst_name unless tst.empty?

    FailedTestType.find_or_create_by(test_type: test_name, reason: 'Test Type not avail in NLIMS')
    false
  end

  def self.get_order_by_tracking_number_sql(track_number)
    details = Speciman.where(tracking_number: track_number).first
    details || false
  end

  def self.query_results_by_npid(npid)
    ord = Speciman.find_by_sql("SELECT specimen.id AS trc, specimen.tracking_number AS track,
																specimen_types.name AS spec_name FROM specimen
																INNER JOIN specimen_types ON specimen_types.id = specimen.specimen_type_id
																INNER JOIN tests ON tests.specimen_id = specimen.id
																INNER JOIN patients ON patients.id = tests.patient_id
																WHERE patients.patient_number='#{npid}'")
    info = {}
    if !ord.empty?
      checker = false
      ord.each do |ord_lo|
        r = Test.find_by_sql("SELECT test_types.name AS tst_type, tests.id AS tst_id FROM test_types
															INNER JOIN tests ON test_types.id = tests.test_type_id
															INNER JOIN specimen ON specimen.id = tests.specimen_id
															WHERE specimen.id ='#{ord_lo.trc}'")
        unless r.empty?
          test_re = {}
          r.each do |te|
            res = Speciman.find_by_sql("SELECT measures.name AS measure_name, test_results.result AS result,
																				tests.id AS tstt_id
																				FROM specimen INNER JOIN tests ON tests.specimen_id = specimen.id
																				INNER JOIN test_results ON test_results.test_id = tests.id
																				INNER JOIN measures ON measures.id = test_results.measure_id
																				WHERE specimen.id  = '#{ord_lo.trc}' AND
																				test_results.test_id ='#{te.tst_id}'")
            results = {}
            if !res.empty?
              res.each do |re|
                results[re.measure_name] = re.result
              end
              ts_name_ = TestStatusTrail.find_by_sql("SELECT max(test_status_trails.created_at),
																									test_statuses.name AS st_name
																									FROM test_statuses
																									INNER JOIN test_status_trails
																									ON test_status_trails.test_status_id =
																									test_statuses.id
																									INNER JOIN tests ON tests.id =
																									test_status_trails.test_id
																									WHERE tests.id='#{te.tst_id}' GROUP BY test_statuses.name
																									")
              ts_name_ = ts_name_[0].st_name
              test_re[te.tst_type] = {
                'test_result': results,
                'test_status': ts_name_
              }
              checker = true
            else
              test_re[te.tst_type] = {}
            end
          end

        end
        info[ord_lo.track] = {
          'sample_type': ord_lo.spec_name,
          'tests': test_re
        }
      end
      if checker == true
        info
      else
        checker
      end
    else
      false
    end
  end

  def self.query_results_by_tracking_number(tracking_number)
    r = Test.find_by_sql("SELECT test_types.name AS tst_type, tests.id AS tst_id FROM test_types
													INNER JOIN tests ON test_types.id = tests.test_type_id
													INNER JOIN specimen ON specimen.id = tests.specimen_id
													WHERE specimen.tracking_number ='#{tracking_number}'")
    checker = false
    r_date = ''
    if !r.empty?
      test_re = {}
      r.each do |te|
        res = Speciman.find_by_sql("SELECT measures.name AS measure_name, test_results.result AS result,
																		test_results.time_entered AS time_entered
																		FROM specimen INNER JOIN tests ON tests.specimen_id = specimen.id
																		INNER JOIN test_results ON test_results.test_id = tests.id
																		INNER JOIN measures ON measures.id = test_results.measure_id
																		WHERE specimen.tracking_number  = '#{tracking_number}' AND
																		test_results.test_id ='#{te.tst_id}'")
        results = {}
        if res.length > 0
          res.each do |re|
            results[re.measure_name] = re.result
            r_date = re.time_entered
          end
          results['result_date'] = begin
            r_date.to_date
          rescue StandardError
            nil
          end
          test_re[te.tst_type] = results
          checker = true
        else
          test_re[te.tst_type] = {}
        end
      end
      if checker == true
        test_re
      else
        checker
      end
    else
      false
    end
  end

  def self.retrieve_undispatched_samples(facilities)
    master_facility = {}
    facility_samples = []
    facilities.each do |facility|
      res = Site.find_by_sql("SELECT name AS site_name FROM sites WHERE id='#{facility}'")
      unless res.blank?
        ActiveRecord::Base.connection.execute("SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION'")
        res_ = Speciman.find_by_sql("SELECT specimen.tracking_number AS tracking_number,
																		specimen_types.name AS sample_type, specimen_statuses.name AS specimen_status,
																		wards.name AS order_location, specimen.date_created AS date_created,
																		specimen.priority AS priority,
																		specimen.drawn_by_id AS drawer_id, specimen.drawn_by_name AS drawer_name,
																		specimen.drawn_by_phone_number AS drawe_number, specimen.target_lab AS target_lab,
																		specimen.sending_facility AS health_facility, specimen.requested_by AS requested_by,
																		specimen.date_created AS date_drawn,
																		patients.patient_number AS pat_id, patients.name AS pat_name,
																		patients.dob AS dob, patients.gender AS sex,
                                    specimen.arv_number AS arv_number
																		FROM specimen INNER JOIN specimen_statuses ON specimen_statuses.id = specimen.specimen_status_id
																		LEFT JOIN specimen_types ON specimen_types.id = specimen.specimen_type_id
																		INNER JOIN tests ON tests.specimen_id = specimen.id
																		INNER JOIN patients ON patients.id = tests.patient_id
																		LEFT JOIN wards ON specimen.ward_id = wards.id
						      									WHERE specimen.sending_facility ='#{res[0]['site_name'].gsub("'", "\\\\'")}'
																		AND specimen.tracking_number NOT IN (SELECT tracking_number FROM specimen_dispatches)
																		GROUP BY specimen.id ORDER BY specimen.id DESC limit 500")
        tsts = {}
        if !res_.empty?
          res_.each do |ress|
            tst = Test.find_by_sql("SELECT test_types.name AS test_name, test_statuses.name AS test_status
																	FROM tests
																	INNER JOIN specimen ON specimen.id = tests.specimen_id
																	INNER JOIN test_types ON test_types.id = tests.test_type_id
																	INNER JOIN test_statuses ON test_statuses.id = tests.test_status_id
																	WHERE specimen.tracking_number ='#{ress.tracking_number}'")
            unless tst.empty?
              tst.each do |t|
                tsts[t.test_name] = t.test_status
              end
            end
            facility_samples.push(
              {
                tracking_number: ress.tracking_number,
                sample_type: ress.sample_type,
                specimen_status: ress.specimen_status,
                order_location: ress.order_location,
                date_created: ress.date_created,
                priority: ress.priority,
                receiving_lab: ress.target_lab,
                sending_lab: ress.health_facility,
                requested_by: ress.requested_by,
                sample_created_by: {
                  id: ress.drawe_number,
                  name: ress.drawer_name,
                  phone: ress.drawe_number
                },
                patient: {
                  id: ress.pat_id,
                  name: ress.pat_name,
                  gender: ress.sex,
                  dob: ress.dob,
                  arv_number: ress.arv_number
                },

                tests: tsts
              }
            )
            tsts = {}
          end

        else
          facility_samples.push('N/A')
        end

      end
      master_facility[facility.to_s] = facility_samples
      facility_samples = []
    end
    [true, master_facility]
  end

  def self.retrieve_samples(date, date_from, region)
    orders = Speciman.find_by_sql("SELECT specimen_types.name AS sample_type, specimen_statuses.name AS specimen_status,
                  specimen.tracking_number AS tracking_number,
                  wards.name AS order_location, specimen.date_created AS date_created, specimen.priority AS priority,
                  specimen.drawn_by_id AS drawer_id, specimen.drawn_by_name AS drawer_name,
                  specimen.drawn_by_phone_number AS drawe_number, specimen.target_lab AS target_lab,
                  specimen.sending_facility AS health_facility, specimen.requested_by AS requested_by,
                  specimen.date_created AS date_drawn,
                  patients.patient_number AS pat_id, patients.name AS pat_name,
                  patients.dob AS dob, patients.gender AS sex,
                  art_regimen AS art_regi, arv_number AS arv_number,
                  art_start_date AS art_start_date
                  FROM specimen INNER JOIN specimen_statuses ON specimen_statuses.id = specimen.specimen_status_id
                  LEFT JOIN specimen_types ON specimen_types.id = specimen.specimen_type_id
                  INNER JOIN tests ON tests.specimen_id = specimen.id
                  INNER JOIN patients ON patients.id = tests.patient_id
                  LEFT JOIN wards ON specimen.ward_id = wards.id
                  INNER JOIN test_types ON test_types.id = tests.test_type_id
                  INNER JOIN sites ON sites.name = specimen.sending_facility
            WHERE (substr(specimen.created_at,1,10) BETWEEN '#{date_from}' AND '#{date}')
            AND (test_types.name ='Viral Load' AND sites.region='#{region}') GROUP BY specimen.id DESC limit 35000")
    tsts = {}
    data = []
    counter = 0
    if orders.length > 0
      orders.each do |res|
        tracking_number = res.tracking_number
        site_code_number = get_site_code_number(tracking_number)
        tst = Test.find_by_sql("SELECT test_types.name AS test_name, test_statuses.name AS test_status
                                                FROM tests
                                                INNER JOIN specimen ON specimen.id = tests.specimen_id
                                                INNER JOIN test_types ON test_types.id = tests.test_type_id
                                                INNER JOIN test_statuses ON test_statuses.id = tests.test_status_id
                                                WHERE specimen.tracking_number ='#{tracking_number}'")
        if tst.length > 0
          tst.each do |t|
            tsts[t.test_name] = t.test_status
          end
        end
        patient_name = res.pat_name.gsub("'", ' ')
        drawer_name = res.drawer_name.gsub("'", ' ')
        arv_number = res.arv_number
        if arv_number.present?
          arv_number = arv_number.split('-')
          arv_number = arv_number[arv_number.length - 1]
        end
        next if tracking_number[0..4] == 'XCHSU'

        dob = res.dob
        dob = Time.new.strftime('%Y-%m-%d') if dob.nil?
        data[counter] = { sample_type: res.sample_type,
                          tracking_number:,
                          specimen_status: res.specimen_status,
                          order_location: res.order_location,
                          date_created: res.date_created,
                          priority: res.priority,
                          art_regimen: res.art_regi,
                          arv_number:,
                          site_code_number:,
                          art_start_date: res.art_start_date,
                          sample_created_by: {
                            id: res.drawe_number,
                            name: drawer_name,
                            phone: res.drawe_number
                          },
                          patient: {
                            id: res.pat_id,
                            name: patient_name,
                            gender: res.sex,
                            dob:
                          },
                          receiving_lab: res.target_lab,
                          sending_lab: res.health_facility,
                          sending_lab_code: site_code_number,
                          requested_by: res.requested_by,
                          tests: tsts }
        counter += 1
      end
      counter = 0
      data
    else
      false
    end
  end

  def self.dispatch_sample(tracking_n, dispatcher, date_dispatched, dispatcher_type_id, delivery_location = 'pickup')
    tracking_number = tracking_n.strip
    return true if check_if_dispatched(tracking_number, dispatcher_type_id)

    tracking_number = tracking_number.encode('UTF-8', 'ISO-8859-1')
    SpecimenDispatch.find_or_create_by(tracking_number:, dispatcher_type_id:)
                    .update(dispatcher:, date_dispatched:, delivery_location:)
    true
  end

  def self.check_if_dispatched(tracking_number, dispatcher_type_id)
    tracking_number = tracking_number.encode('UTF-8', 'ISO-8859-1')
    SpecimenDispatch.find_by(tracking_number:, dispatcher_type_id:).present?
  end

  def self.request_order(params, tracking_number)
    ActiveRecord::Base.transaction do
      npid = params[:national_patient_id]
      patient_obj = Patient.where(patient_number: npid)
      patient_obj = patient_obj.first unless patient_obj.blank?
      if patient_obj.blank?
        patient_obj = patient_obj.create(
          patient_number: npid,
          name: "#{params[:first_name]} #{params[:last_name]}",
          email: '',
          dob: params[:date_of_birth],
          gender: params[:gender],
          phone_number: params[:phone_number],
          address: '',
          external_patient_number: ''
        )

      else
        patient_obj.dob = params[:date_of_birth]
        patient_obj.name = "#{params[:first_name]} #{params[:last_name]}"
        patient_obj.save
      end
      time = params[:date_sample_drawn].blank? ? Date.today : params[:date_sample_drawn]
      sample_status_id = SpecimenStatus.get_specimen_status_id('specimen_not_collected')
      sp_obj = Speciman.create(
        tracking_number:,
        specimen_type_id: 0,
        specimen_status_id: sample_status_id,
        couch_id: SecureRandom.uuid,
        ward_id: Ward.get_ward_id(params[:order_location]),
        priority: params[:sample_priority],
        drawn_by_id: params[:who_order_test_id],
        drawn_by_name: "#{params[:who_order_test_first_name]} #{params[:who_order_test_last_name]}",
        drawn_by_phone_number: params[:who_order_test_phone_number],
        target_lab: params[:target_lab],
        art_start_date: params[:art_start_date] || '',
        sending_facility: params[:health_facility_name],
        requested_by: params[:requesting_clinician],
        district: params[:district],
        date_created: time,
        arv_number: params[:arv_number] || 'N/A',
        art_regimen: params[:art_regimen] || 'N/A'
      )
      res = Visit.create(
        patient_id: npid,
        visit_type_id: '',
        ward_id: Ward.get_ward_id(params[:order_location])
      )
      params[:tests].each do |tst|
        tst = NameMapping.actual_name_of(tst)
        status = check_test(tst)
        if status == false
          rst = TestType.get_test_type_id(tst)
          rst2 = TestStatus.get_test_status_id('drawn')
          Test.create(
            specimen_id: sp_obj.id,
            test_type_id: rst,
            patient_id: patient_obj.id,
            created_by: "#{params[:who_order_test_first_name]} #{params[:who_order_test_last_name]}",
            panel_id: '',
            time_created: time,
            test_status_id: rst2
          )
        else
          pa_id = PanelType.where(name: tst).first
          res = TestType.find_by_sql("SELECT test_types.id FROM test_types INNER JOIN panels
																			ON panels.test_type_id = test_types.id
																			INNER JOIN panel_types ON panel_types.id = panels.panel_type_id
																			WHERE panel_types.id ='#{pa_id.id}'")
          res.each do |tt|
            rst2 = TestStatus.get_test_status_id('drawn')
            Test.create(
              specimen_id: sp_obj.id,
              test_type_id: tt.id,
              patient_id: patient_obj.id,
              created_by: "#{params[:who_order_test_first_name]} #{params[:who_order_test_last_name]}",
              panel_id: '',
              time_created: time,
              test_status_id: rst2
            )
          end
        end
      end
    end
    sp = Speciman.find_by(tracking_number:)
    [true, tracking_number, sp&.couch_id]
  end

  def self.confirm_order_request(params)
    order = Speciman.find_by(tracking_number: params['tracking_number'])
    specimen_type = SpecimenType.find_by(name: params['specimen_type'])
    order.update(
      specimen_type_id: specimen_type.id,
      specimen_status_id: SpecimenStatus.get_specimen_status_id('specimen_collected'),
      target_lab: params['target_lab']
    )
  end

  def self.query_requested_order_by_npid(npid)
    r = Speciman.find_by_sql("SELECT distinct(specimen.id) FROM specimen
															INNER JOIN tests ON specimen.id = tests.specimen_id
															INNER JOIN patients ON patients.id = tests.patient_id
															WHERE patients.patient_number = '#{npid}'")
    if !r.empty?
      counter = 0
      details = []
      det = {}
      checker = []
      tste = []
      r.each do |data|
        tra_num = data['id']
        next if checker.include?(tra_num)

        da = Speciman.find_by_sql("SELECT * FROM specimen WHERE id='#{tra_num}'")
        checker.push(tra_num)
        tst = Test.find_by_sql("SELECT * FROM tests
																INNER JOIN test_types ON tests.test_type_id = test_types.id
																WHERE tests.specimen_id='#{data['id']}'")
        unless tst.empty?
          tst.each do |t_name|
            tste.push(t_name['name'])
          end
        end
        set_specimen_type_id = da[0]['specimen_type_id'].to_i
        set_specimen_type_id = 'not-assigned' if set_specimen_type_id.zero?
        begin
          if set_specimen_type_id != 'not-assigned' && !set_specimen_type_id.blank?
            spc_type = SpecimenType.find_by_sql("SELECT name FROM specimen_types
																								WHERE id ='#{set_specimen_type_id}'")[0]['name']
          end
          spc_type = 'not-assigned' if set_specimen_type_id == 'not-assigned' || set_specimen_type_id.blank?
        rescue StandardError
          next
        end
        det = {
          requested_by: da[0]['requested_by'],
          date_created: da[0]['date_created'],
          specimen_type: spc_type,
          tracking_number: da[0]['tracking_number'],
          tests: tste
        }
        details[counter] = det
        det = {}
        tste = []
        counter += 1
      end
      details
    else
      false
    end
  end

  def self.query_order_by_npid(npid)
    res = Speciman.find_by_sql("SELECT specimen_types.name AS spc_type, specimen.tracking_number AS track_number,
		 														specimen.id AS _id,specimen.date_created AS dat_created
																FROM specimen INNER JOIN specimen_types
																ON specimen_types.id = specimen.specimen_type_id")

    counter = 0
    details = []
    det = {}
    tste = []
    got_tsts = false

    if !res.empty?
      res.each do |gde|
        specimen_id = gde['_id']
        tst = Speciman.find_by_sql("SELECT test_types.name AS tst_name FROM test_types
																		INNER JOIN tests ON tests.test_type_id = test_types.id
																		INNER JOIN specimen  ON specimen.id = tests.specimen_id
																		INNER JOIN patients ON patients.id = tests.patient_id
																		WHERE tests.specimen_id ='#{specimen_id}' AND patients.patient_number ='#{npid}'")
        tst.each do |ty|
          tste.push(ty['tst_name'])
          got_tsts = true
        end
        next unless got_tsts == true

        det = {
          specimen_type: gde['spc_type'],
          tracking_number: gde['track_number'],
          date_created: gde['dat_created'],
          tests: tste
        }
        details[counter] = det
        counter += 1
        tste = []
        got_tsts = false
      end
      counter = 0
      details
    else
      false
    end
  end

  def self.check_test(tst)
    res = PanelType.find_by_sql("SELECT * FROM panel_types WHERE name ='#{tst}'")
    !res.empty?
  end

  def self.check_if_order_updated?(tracking_number, status_id)
    obj = Speciman.find_by(tracking_number:, specimen_status_id: status_id)
    if !obj.blank?
      true
    else
      false
    end
  end

  def self.update_order(params)
    return [false, 'no tracking number'] if params['tracking_number'].blank?

    specimen_status = SpecimenStatus.find_by(name: params['status'])
    return [false, 'wrong parameter for specimen status'] if specimen_status.blank?

    order = Speciman.find_by(tracking_number: params['tracking_number'])
    unless params['specimen_type'].blank?
      specimen_type = SpecimenType.find_by(name: params['specimen_type'])
      return [false, 'wrong parameter for specimen type'] if specimen_type.blank?

      order.update(specimen_type_id: specimen_type.id)
    end
    order.update(specimen_status_id: specimen_status.id)
    SpecimenStatusTrail.create(
      specimen_id: order.id,
      specimen_status_id: specimen_status.id,
      time_updated: Time.new.strftime('%Y%m%d%H%M%S'),
      who_updated_id: params['who_updated']['id'],
      who_updated_name: "#{params['who_updated']['first_name']} #{params['who_updated']['last_name']}",
      who_updated_phone_number: params['who_updated']['phone_number']
    )
    [true, '']
  end

  def self.query_order_by_tracking_number(tracking_number)
    res = Speciman.find_by_sql("SELECT specimen_types.name AS sample_type, specimen_statuses.name AS specimen_status,
                              wards.name AS order_location, specimen.date_created AS date_created, specimen.priority AS priority,
                              specimen.drawn_by_id AS drawer_id, specimen.drawn_by_name AS drawer_name,
                              specimen.drawn_by_phone_number AS drawe_number, specimen.target_lab AS target_lab,
                              specimen.sending_facility AS health_facility, specimen.requested_by AS requested_by,
                              specimen.date_created AS date_drawn,
                              patients.patient_number AS pat_id, patients.name AS pat_name,
                              patients.dob AS dob, patients.gender AS sex,
                              art_regimen AS art_regi, arv_number AS arv_number,
                              art_start_date AS art_start_date
                              FROM specimen INNER JOIN specimen_statuses ON specimen_statuses.id = specimen.specimen_status_id
                              LEFT JOIN specimen_types ON specimen_types.id = specimen.specimen_type_id
                              INNER JOIN tests ON tests.specimen_id = specimen.id
                              INNER JOIN patients ON patients.id = tests.patient_id
                              LEFT JOIN wards ON specimen.ward_id = wards.id
                              WHERE specimen.tracking_number ='#{tracking_number}' ")
    tsts = {}
    if !res.empty?
      site_code_number = get_site_code_number(tracking_number)
      res = res[0]
      tst = Test.find_by_sql("SELECT test_types.name AS test_name, test_statuses.name AS test_status
															FROM tests
															INNER JOIN specimen ON specimen.id = tests.specimen_id
															INNER JOIN test_types ON test_types.id = tests.test_type_id
                              INNER JOIN test_statuses ON test_statuses.id = tests.test_status_id
															WHERE specimen.tracking_number ='#{tracking_number}'")
      unless tst.empty?
        tst.each do |t|
          tsts[t.test_name] = t.test_status
        end
      end
      arv_number = res.arv_number
      if arv_number.present?
        arv_number = arv_number.split('-')
        arv_number = arv_number[arv_number.length - 1]
      end
      {
        gen_details: {
          sample_type: res.sample_type,
          specimen_status: res.specimen_status,
          order_location: res.order_location,
          date_created: res.date_created,
          priority: res.priority,
          art_regimen: res.art_regi,
          arv_number:,
          site_code_number:,
          art_start_date: res.art_start_date,
          sample_created_by: {
            id: res.drawe_number,
            name: res.drawer_name,
            phone: res.drawe_number
          },
          patient: {
            id: res.pat_id,
            name: res.pat_name,
            gender: res.sex,
            dob: res.dob
          },
          receiving_lab: res.target_lab,
          sending_lab: res.health_facility,
          sending_lab_code: site_code_number,
          requested_by: res.requested_by
        },
        tests: tsts
      }
    else
      false
    end
  end
end
