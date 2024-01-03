require 'order_service'
module TestService
  def self.update_test(params)
    return [false, 'tracking number not provided'] if params[:tracking_number].blank?
    return [false, 'test name not provided'] if params[:test_name].blank?
    return [false, 'test status not provided'] if params[:test_status].blank?

    sql_order = OrderService.get_order_by_tracking_number_sql(params[:tracking_number])
    result_date = if params[:result_date].blank?
                    Time.now.strftime('%Y%m%d%H%M%S')
                  else
                    params[:result_date]
                  end
    if !sql_order == false
      order_id = sql_order.id
      couch_id = sql_order.couch_id
      test_name = NameMapping.actual_name_of(params[:test_name])
      retr_order = OrderService.retrieve_order_from_couch(couch_id)
      tst_name__ = TestType.find_by(name: test_name)
      status__ = TestStatus.find_by(name: params[:test_status])
      return [false, 'wrong parameter on test name provided'] if tst_name__.blank?
      return [false, 'test status provided, not within scope of tests statuses'] if status__.blank?

      test_id = Test.find_by_sql("SELECT tests.id FROM tests INNER JOIN test_types ON tests.test_type_id = test_types.id
																	WHERE tests.specimen_id = '#{order_id}' AND test_types.name = '#{test_name}'")
      test_status = TestStatus.where(name: params[:test_status]).first
      couch_id_updater = 0
      if !test_id.blank?
        checker = check_if_test_updated?(test_id, test_status.id)
        if checker == false
          ts = test_id[0]
          test_id = ts['id']
          couch_test = {}
          time = Time.now.strftime('%Y%m%d%H%M%S')
          details = {
            'status' => params[:test_status],
            "updated_by": {
              first_name: params[:who_updated]['first_name'],
              last_name: params[:who_updated]['last_name'],
              phone_number: '',
              id: params[:who_updated]['id_number']
            }
          }
          couch_test[test_name] = details
          test_results_measures = {}
          results_measure = {}
          TestStatusTrail.create(
            test_id: test_id,
            time_updated: params[:time_updated],
            test_status_id: test_status.id,
            who_updated_id: params[:who_updated]['id_number'].to_s,
            who_updated_name: "#{params[:who_updated]['first_name']} #{params[:who_updated]['last_name']}",
            who_updated_phone_number: ''
          )
          test_status = TestStatus.where(name: params[:test_status]).first
          tst_update = Test.find_by(id: test_id)
          couch_id_updater = tst_update.test_status_id
          if tst_update.test_status_id == 9 && test_status.id == 2
            tst_update.test_status_id = test_status.id
            tst_update.save
          elsif tst_update.test_status_id == 2 && test_status.id == 3
            tst_update.test_status_id = test_status.id
            tst_update.save
          elsif tst_update.test_status_id == 3 && test_status.id == 4
            tst_update.test_status_id = test_status.id
            tst_update.save
          elsif tst_update.test_status_id == 4 && test_status.id == 5
            tst_update.test_status_id = test_status.id
            tst_update.save
          elsif test_status.id == 11
            tst_update.test_status_id = test_status.id
            tst_update.save
          elsif test_status.id == 10
            tst_update.test_status_id = test_status.id
            tst_update.save
          end
          if params[:results]
            results = params[:results]
            results.each do |key, value|
              measure_name = key
              result_value = value
              measure = Measure.where(name: measure_name).first
              next if measure.blank?

              if check_if_result_already_available(test_id, measure.id) == false
                device_name = params[:platform].blank? ? '' : params[:platform]
                next if result_value == 'Failed' && test_name == 'Viral Load'

                TestResult.create(
                  measure_id: measure.id,
                  test_id: test_id,
                  result: result_value,
                  device_name: device_name,
                  time_entered: result_date
                )
              else
                test_result_ = TestResult.where(test_id: test_id, measure_id: measure.id).first
                test_result_.update(result: result_value, time_entered: result_date)
                t = TestStatusTrail.where(test_id: test_id, test_status_id: 5).first
                t.update(time_updated: result_date) unless t.blank?
              end
              test_results_measures[measure_name] = { 'result_value': result_value }
            end
            results_measure[test_name] = test_results_measures
          end
          if retr_order != 'false'
            couch_test_statuses = retr_order['test_statuses'][test_name]
            couch_test_statuses[time] = details unless couch_test_statuses.blank?

            retr_order['test_statuses'][test_name] = couch_test_statuses
            unless results_measure.blank?
              retr_order['test_results'][test_name] = {
                'results': test_results_measures,
                'date_result_entered': result_date,
                'result_entered_by': {
                  first_name: params[:who_updated]['first_name'],
                  last_name: params[:who_updated]['last_name'],
                  phone_number: '',
                  id: params[:who_updated]['id_number']
                }
              }
            end
            if couch_id_updater == 9 && params[:test_status] == 'started'
              OrderService.update_couch_order(couch_id, retr_order)
            elsif couch_id_updater == 3 && params[:test_status] == 'completed'
              OrderService.update_couch_order(couch_id, retr_order)
            elsif couch_id_updater == 4 && params[:test_status] == 'verified'
              OrderService.update_couch_order(couch_id, retr_order)
            elsif params[:test_status] == 'test-rejected'
              OrderService.update_couch_order(couch_id, retr_order)
            elsif params[:test_status] == 'rejected'
              OrderService.update_couch_order(couch_id, retr_order)
            end
          end
          [true, '']
        else
          [false, 'order already updated with such state']
        end
      else
        [false, 'order with such test not available']
      end
    else
      [false, 'order not available']
    end
  end

  def self.check_if_test_updated?(test_id, status_id)
    obj = Test.find_by(id: test_id, test_status_id: status_id)
    if !obj.blank?
      !(status_id == 5)
    else
      false
    end
  end

  def self.check_if_result_already_available(test_id, measure_id)
    res = TestResult.find_by_sql("SELECT * FROM test_results where test_id=#{test_id} AND measure_id=#{measure_id}")
    if !res.blank?
      true
    else
      false
    end
  end

  def self.acknowledge_test_results_receiptient(tracking_number, test_name, date, recipient_type)
    test_name = 'Viral Load' if test_name == 'HIV viral load'
    test_name = 'CD4' if test_name == 'CD4 count'
    res = Test.find_by_sql("SELECT tests.id FROM tests INNER JOIN test_types ON test_types.id = tests.test_type_id
                                                        INNER JOIN specimen ON specimen.id = tests.specimen_id
                                                        where specimen.tracking_number ='#{tracking_number}' AND test_types.name='#{test_name}'")

    if !res.blank?

      type = TestResultRecepientType.find_by(name: recipient_type)
      tst = Test.find_by(id: res[0]['id'])
      tst.test_result_receipent_types = type.id
      tst.result_given = true
      tst.date_result_given = date
      tst.save
      obj = Speciman.find_by(tracking_number: tracking_number)
      couch_id = obj['couch_id'] unless obj['couch_id'].blank?

      retr_order = OrderService.retrieve_order_from_couch(couch_id)
      unless retr_order['tracking_number'].blank?
        test_ackn = {}
        test_ackn[test_name] = {
          'result_recepient_type': recipient_type,
          'result_given': 'true',
          'date_result_give;': date
        }
        new_acknow = test_ackn
        retr_order['results_acknowledgement'] = new_acknow
        OrderService.update_couch_order(couch_id, retr_order)
      end

      true
    else
      false
    end
  end

  def self.test_no_results(npid)
    res = Test.find_by_sql("SELECT tests.time_created,test_types.name, test_statuses.name AS test_status, tests.id AS tst_id, specimen.tracking_number
							FROM tests INNER JOIN test_statuses ON test_statuses.id = tests.test_status_id INNER JOIN test_types
							ON test_types.id = tests.test_type_id
							INNER JOIN patients ON patients.id = tests.patient_id
							INNER JOIN specimen ON specimen.id = tests.specimen_id
							WHERE patients.patient_number='#{npid}' AND (tests.test_status_id != '4' AND tests.test_status_id != '5')")
    data = []
    if !res.blank?
      res.each do |d|
        data.push({ 'tracking_number': d['tracking_number'], 'test_name': d['name'], 'created_at': d['time_created'].to_date,
                    'status': d['test_status'] })
      end
      [true, data]
    else
      [false, '']
    end
  end

  def self.query_test_status(tracking_number)
    spc_id = Speciman.find_by(tracking_number: tracking_number)['id']
    status = Test.find_by_sql("SELECT test_statuses.name,test_types.name AS tst_name FROM test_statuses INNER JOIN tests ON tests.test_status_id = test_statuses.id
							INNER JOIN test_types ON test_types.id = tests.test_type_id
							WHERE tests.specimen_id='#{spc_id}'
						")

    if !status.blank?
      st = status.collect do |s|
        { s['tst_name'] => s['name'] }
      end
      [true, st]
    else
      [false, '']
    end
  end

  def self.query_test_measures(test_name)
    test_name = test_name.gsub('_', ' ')
    test_type_id = TestType.find_by(name: test_name)['id']
    res = TesttypeMeasure.find_by_sql("SELECT measures.name FROM testtype_measures INNER JOIN measures
									ON measures.id = testtype_measures.measure_id
									INNER JOIN test_types ON test_types.id = testtype_measures.test_type_id
									WHERE test_types.id='#{test_type_id}'
								")

    if !res.blank?
      res.collect do |t|
        t['name']
      end
    else
      false
    end
  end

  def self.add_test(params)
    tests = params['tests']
    tracking_number = params['tracking_number']
    sql_order = OrderService.get_order_by_tracking_number_sql(tracking_number)
    return [false, 'order not available'] if sql_order == false

    spec_id = sql_order.id
    updater = params['who_updated']
    res = Test.find_by_sql("SELECT patient_id AS patient_id FROM tests WHERE specimen_id='#{spec_id}' LIMIT 1")
    patient_id = res[0]['patient_id']
    order = OrderService.retrieve_order_from_couch(sql_order.couch_id)
    return [false, 'order not available -c'] if order == 'false'

    tet = []
    test_results = {}
    details = {}
    tet = order['tests']
    test_results = order['test_results']
    test_statuses = order['test_statuses']
    tests.each do |tst|
      te_id = TestType.where(name: tst).first
      return [false, 'test name not available at national lims'] if te_id.blank?

      Test.create(
        specimen_id: spec_id,
        test_type_id: te_id.id,
        created_by: updater['first_name'].to_s + ' ' + updater['last_name'].to_s,
        panel_id: '',
        patient_id: patient_id,
        time_created: Time.now.strftime('%Y%m%d%H%M%S'),
        test_status_id: TestStatus.find_by_sql("SELECT id AS sts_id FROM test_statuses WHERE name='Drawn'")[0]['sts_id']
      )
      tet.push(tst)
      test_results[tst] = {
        'results': {},
        'date_result_entered': '',
        'result_entered_by': {}
      }
      time = Time.new.strftime('%Y%m%d%H%M%S')
      details[time] = {
        'status' => 'Drawn',
        "updated_by": {
          first_name: updater['first_name'],
          last_name: updater['last_name'],
          phone_number: updater['phone_number'],
          id: updater['id_number']
        }
      }
      test_statuses[tst] = details
    end

    order['tests'] = tet
    order['test_results'] = test_results
    order['test_statuses'] = test_statuses

    OrderService.update_couch_order(sql_order.id, order)
    true
  end

  def self.retrieve_test_catelog
    if File.exist?("#{Rails.root}/public/test_catelog.json")
      dat = File.read("#{Rails.root}/public/test_catelog.json")
      JSON.parse(dat)
    else
      false
    end
  end

  def self.retrieve_order_location
    re = Ward.find_by_sql('SELECT wards.name FROM wards')
    if !re.blank?
      re.collect do |t|
        t['name']
      end
    else
      false
    end
  end

  def self.retrieve_target_labs
    re = Site.find_by_sql('SELECT sites.name FROM sites')
    if !re.blank?
      re.collect do |t|
        t['name']
      end
    else
      false
    end
  end

  def self.get_order_test(params)
    tracking_number = params[:tracking_number]
    res1 = TestType.find_by_sql(
      "SELECT test_types.name AS test_name, test_types.id AS tes_id FROM test_types
								INNER JOIN tests ON tests.test_type_id = test_types.id
								INNER JOIN specimen ON tests.specimen_id = specimen.id
								WHERE specimen.tracking_number = '#{tracking_number}'"
    )
    details = {}
    measures = {}
    ranges = []
    unless res1.blank?
      res1.each do |te|
        res = Speciman.find_by_sql("SELECT measures.name AS measure_nam, measures.id AS me_id FROM measures
								INNER JOIN testtype_measures ON testtype_measures.measure_id = measures.id
								INNER JOIN test_types ON test_types.id = testtype_measures.test_type_id
								WHERE test_types.id = '#{te.tes_id}'
							")
        next if res.blank?

        res.each do |me|
          me_ra = MeasureRange.find_by_sql("SELECT measure_ranges.alphanumeric AS alpha FROM measure_ranges
											WHERE measures_id ='#{me.me_id}'")
          me_ra.each do |r|
            if r.alpha.blank?
              ranges.push('free text')
            else
              ranges.push(r.alpha)
            end
          end
          measures[me.measure_nam] = ranges
          ranges = []
        end
        details[te.test_name] = measures
        measures = {}
      end
    end
    details
  end
end
