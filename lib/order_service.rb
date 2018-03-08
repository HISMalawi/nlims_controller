
module  OrderService

	def self.create_order(params,tracking_number)
		ActiveRecord::Base.transaction do 

			npid = params[:national_patient_id]
			patient_obj = Patient.where(patient_id: npid)

			patient_obj = patient_obj.first unless patient_obj.blank?
				if patient_obj.blank?
					pat = CouchPatient.create()
					patient_obj.create(patient_id: npid, name: '')
				end

                  #obtaining order details posted by client

			sample_type = SpecimenType.where(name: params[:sample_type]).first
                  sample_collector_name = params[:sample_collector_first_name] + " " + params[:sample_collector_last_name]
                  sample_collector_phone_number = params[:sample_collector_phone_number]
                  sample_collector_id = params[:sample_collector_id]
                  sample_order_location = params[:sample_order_location]
                  requesting_clinician = params[:requesting_clinician]
                  date_sample_drawn = params[:date_sample_drawn]
                  date_created = params[:date_created]
                  sample_priority = params[:sample_priority]
                  target_lab = params[:target_lab]
                  art_start_date = params[:art_start_date]
                  health_facility_name = params[:health_facility_name]
                  health_facility_district = params[:health_facility_district]
                  specimen_status = SpecimenStatus.where(name: 'specimen_accepted').first

                  sample_collector = {
                                    id: sample_collector_id,
                                    first_name: sample_collector_name.split(" ")[0],
                                    last_name: sample_collector_name.split(" ")[1],
                                    phone_number: sample_collector_phone_number
                  }

			c_order  = CouchOrder.create(
                                                tracking_number: tracking_number,
                                                date_created: date_created,
                                                priority: sample_priority,
                                                specimen_status: specimen_status.id,
                                                sample_collector: sample_collector,
                                                patient_id: npid, 
                                                sample_type: sample_type.id,
                                                target_lab: target_lab,
                                                art_start_date: art_start_date,
                                                health_facility: health_facility_name,
                                                ward_or_location: sample_order_location,
                                                requested_by: requesting_clinician,
                                                date_sample_drawn: date_sample_drawn,
                                                date_created: date_created,
                                                health_facility_district: health_facility_district
                              )

                  ward = Ward.where(name: sample_order_location)

			sq_order = Order.create(
                                                doc_id: c_order.id, 
                                                tracking_number: tracking_number,
                                                patient_id: '11',
                                                specimen_type_id: sample_type.id,
                                                specimen_status_id: specimen_status.id,
                                                date_created: date_created,
                                                priority: sample_priority,
                                                sample_drawn_by_id: sample_collector_id,
                                                sample_drawn_by_name: sample_collector_name,
                                                sample_drawn_by_phone_number: sample_collector_phone_number,
                                                target_lab: target_lab,
                                                art_start_date: art_start_date,
                                                health_facility: health_facility_name,
                                                ward_id:  ward.name,
                                                requested_by: requesting_clinician
                              )



                 tests = TestType.where(name: params[:tests])

			(tests || []).each do |test| 
             
	 			t = CouchTest.create(   order_id: sq_order.id, 
                                                test_type_id: test.id, 
                                                time_created: date_created,
                                                test_status_id: 'Drawn'
                                          )

	 			Test.create(
                                    doc_id: t.id,
                                    order_id: sq_order.id,
                                    test_type_id: test.id,
                                    time_created: date_created,
                                    test_status_id: 'Drawn'
                              )
			end


		end			
            return [true,tracking_number]
	end


      def self.get_order_by_tracking_number_sql(tracking_number)
          details =   Order.where(tracking_number: tracking_number).first
            if details
                  return details
            else
                  return false
            end
      end

      

      def self.query_results_by_tracking_number(tracking_number)

            r = Test.find_by_sql(   "SELECT test_types.name AS tst_type, tests.id AS tst_id FROM test_types
                                    INNER JOIN tests ON test_types.id = tests.test_type_id
                                    INNER JOIN orders ON orders.id = tests.order_id
                                    WHERE orders.tracking_number='#{tracking_number}'"
                  )
            checker = false;
            if r.length > 0
                  test_re = {}
                  r.each do |te|

                        res = Order.find_by_sql( "SELECT measures.name AS measure_name, test_results.result AS result
                                          FROM orders INNER JOIN tests ON tests.order_id = orders.id
                                          INNER JOIN test_results ON test_results.test_id = tests.id
                                          INNER JOIN measures ON measures.id = test_results.measure_id
                                          WHERE orders.tracking_number = '#{tracking_number}' AND 
                                          test_results.test_id ='#{te.tst_id}'"
                                    )
                        results = {}
                       
                        if res.length > 0
                              res.each do |re|

                                  results[re.measure_name] = re.result
                              end
                              test_re[te.tst_type] = results
                              checker = true
                        end

                  end
                  if checker == true
                        return test_re
                  else
                        return checker
                  end
            else
                  return false
            end
      end


      def self.query_order_by_tracking_number(tracking_number)
            res = Order.find_by_sql("SELECT specimen_types.name AS sample_type, specimen_statuses.name AS specimen_status,
                              wards.name AS order_location, orders.date_created AS date_created, orders.priority AS priority,
                              orders.sample_drawn_by_id AS drawer_id, orders.sample_drawn_by_name AS drawer_name,
                              sample_drawn_by_phone_number AS drawe_number, orders.target_lab AS target_lab, 
                              orders.health_facility AS health_facility, orders.requested_by AS requested_by,
                              orders.date_sample_drawn AS date_drawn 
                              FROM orders INNER JOIN specimen_statuses ON specimen_statuses.id = orders.specimen_status_id
                              INNER JOIN specimen_types ON specimen_types.id = orders.specimen_type_id
                              INNER JOIN wards ON wards.id = orders.ward_id
                              WHERE orders.tracking_number ='#{tracking_number}'
                  ")
            tests = {}

            if res.length > 0
                  res = res[0]
                  tst = Test.find_by_sql("SELECT test_types.name AS test_name, test_statuses.name AS test_status
                                          FROM tests
                                          INNER JOIN orders ON orders.id = tests.order_id
                                          INNER JOIN test_types ON test_types.id = tests.test_type_id
                                          INNER JOIN test_statuses ON test_statuses.id = tests.test_status_id
                                          WHERE orders.tracking_number='#{tracking_number}'"
                              )

                  if tst.length > 0
                        tst.each do |t|
                              tests[t.test_name] = t.test_status
                        end
                  end

                  return { 

                        gen_details:   {  sample_type: res.sample_type,
                                          specimen_status: res.specimen_status,
                                          ward: res.order_location,
                                          date_created: res.date_created,
                                          priority: res.priority,
                                          collector: {
                                                      id: res.drawe_number,
                                                      name: res.drawer_name,
                                                      phone: res.drawe_number
                                                },
                                          target_lab: res.target_lab,
                                          health_facility: res.health_facility,
                                          requested_by: res.requested_by,
                                          date_drawn: res.date_drawn
                                          },
                        tests: tests
                  }
                  
            else
                  return false
            end

      end


end






