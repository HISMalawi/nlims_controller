# frozen_string_literal: true

# TestManagement module
module TestManagement
  # TestsService class
  class TestsService
    def self.update_tests(order, params)
      order, lab_test, test_status = validate_test_update_params(order, params)
      return [false, lab_test] if order == false

      ActiveRecord::Base.transaction do
        params[:status_trail].each do |trail|
          trail_status = TestStatus.find_by(name: trail[:status])
          next unless trail_status.present?
          next if TestStatusTrail.exists?(test_id: lab_test.id, test_status_id: trail_status.id)

          TestStatusTrail.create!(
            test_id: lab_test.id,
            time_updated: trail[:timestamp],
            test_status_id: trail_status.id,
            who_updated_id: trail[:updated_by]['id'].to_s,
            who_updated_name: "#{trail[:updated_by]['first_name']} #{trail[:updated_by]['last_name']}",
            who_updated_phone_number: trail[:updated_by]['phone_number'].to_s
          )
        end
        TestManagement::TestStatusUpdaterService.call(lab_test.id, test_status)
        if params[:test_results].present? && test_status&.id == TestStatus.get_test_status_id('verified')
          add_test_results(params, lab_test.id, order)
        end
        [true, 'test updated successfuly']
      rescue StandardError => e
        [false, e.message]
      end
    end

    def self.add_test_results(params, lab_test_id, order)
      params[:test_results].each do |test_result|
        measures = Measure.where(nlims_code: test_result[:measure][:nlims_code]) || Measure.where(name: test_result[:measure][:name])
        measure = TesttypeMeasure.where(test_type_id: Test.find_by(id: lab_test_id)&.test_type_id,
                                        measure_id: measures&.ids)&.first&.measure
        result_params = test_result[:result]
        next if measure.blank?
        next if result_params[:value] == 'Failed'
        next unless result_params[:value].present?

        # Handle special case for Viral Load to remove commas
        result_value = if measure.nlims_code == 'NLIMS_TI_0294_MWI'
                         result_params[:value].gsub(',',
                                                    '')
                       else
                         result_params[:value]
                       end
        next if result_already_available?(lab_test_id, measure.id, result_value)

        previous_result = TestResult.find_by(test_id: lab_test_id, measure_id: measure.id)
        device_name = "#{result_params[:platform]} #{result_params[:platformserial]}".strip
        if previous_result.present?
          TestResultTrail.create!(
            measure_id: measure.id,
            test_id: lab_test_id,
            old_result: previous_result.result,
            new_result: result_value,
            old_device_name: previous_result.device_name,
            new_device_name: device_name,
            old_time_entered: previous_result.time_entered,
            new_time_entered: result_params[:result_date]
          )
          previous_result.update!(result: result_value, time_entered: result_params[:result_date],
                                  unit: result_params[:unit])
          test_status_trail = TestStatusTrail.where(test_id: lab_test_id, test_status_id: 5).first
          test_status_trail.update!(time_updated: result_params[:result_date]) unless test_status_trail.blank?
          result_sync_tracker(order.tracking_number, lab_test_id, force_create: true)
        else
          TestResult.create!(
            measure_id: measure.id,
            test_id: lab_test_id,
            result: result_value,
            device_name: device_name,
            time_entered: result_params[:result_date],
            unit: result_params[:unit]
          )
          result_sync_tracker(order.tracking_number, lab_test_id)
        end
      end
    end

    def self.result_already_available?(test_id, measure_id, value)
      test_result = TestResult.find_by(test_id:, measure_id:)
      return false if test_result.blank?

      test_result&.result == value
    end

    def self.result_sync_tracker(tracking_number, test_id, force_create: false)
      if !Config.local_nlims? && !Config.same_source?(tracking_number) && Config.host_valid?(tracking_number) && !ResultSyncTracker.exists?(
        tracking_number:, test_id:, app: 'nlims'
      )
        ResultSyncTracker.create(tracking_number:, test_id:, app: 'nlims')
      end
      return unless Config.local_nlims?

      if (Config.master_update_source?(tracking_number) || !Config.same_source?(tracking_number)) && !ResultSyncTracker.exists?(
        tracking_number:, test_id:, app: 'emr'
      )
        ResultSyncTracker.create(tracking_number:, test_id:, app: 'emr')
      end
      return if Config.master_update_source?(tracking_number)

      results_exists = ResultSyncTracker.exists?(tracking_number:, test_id:, app: 'nlims')
      return if results_exists && !force_create

      # Create a new ResultSyncTracker record
      ResultSyncTracker.create(tracking_number:, test_id:, app: 'nlims')
    end

    def self.validate_test_update_params(order, params)
      return [false, 'test status not provided'] if params[:test_status].blank?
      return [false, 'test type not provided'] if params.dig(:test_type, :nlims_code).blank?
      return [false, 'time updated not provided'] if params[:time_updated].blank?

      lab_test = Test.joins(:test_type)
                     .where(
                       specimen_id: order.id,
                       test_types: { nlims_code: params.dig(:test_type, :nlims_code) }
                     ).first
      return [false, 'order with such test not available'] unless lab_test

      test_status = TestStatus.find_by(name: params[:test_status])
      unless test_status
        return [false,
                "test status provided, not within scope of tests statuses available:#{TestStatus.all.pluck(:name)}"]
      end

      state, error_message = OrderManagement::OrdersService.validate_time_updated(params[:time_updated], order)
      unless state
        failed_test_update = FailedTestUpdate.find_or_create_by(tracking_number: order.tracking_number,
                                                                test_name: params.dig(:test_type, :name), failed_step_status: test_status&.name)
        failed_test_update.update(error_message: error_message, time_from_source: params[:time_updated])
        return [false, error_message]
      end

      [order, lab_test, test_status]
    end

    def self.acknowledge_test_results_receipt(order, params)
      recipient_type = TestResultRecepientType.find_by(name: params[:recipient_type])
      unless recipient_type.present?
        return [false,
                "recipient type not found - available types are #{TestResultRecepientType.all.pluck(:name)}"]
      end

      test_type = TestType.find_by(nlims_code: params.dig(:test_type, :nlims_code))
      return [false, 'test type not found in nlims'] unless test_type.present?

      lab_test = Test.find_by(specimen_id: order.id, test_type_id: test_type.id)
      return [false, 'test not found for order'] unless lab_test.present?

      return [false, 'date acknowledged not provided'] if params[:date_acknowledged].blank?

      electronically_acknowledged = TestResultRecepientType.find_by(id: lab_test.test_result_receipent_types)&.name == 'test_results_delivered_to_site_electronically'
      if electronically_acknowledged && lab_test.result_given == true
        return [true, 'test result already acknowledged electronically at facility']
      end

      ActiveRecord::Base.transaction do
        lab_test.test_result_receipent_types = recipient_type.id
        lab_test.result_given = true
        lab_test.date_result_given = params[:date_acknowledged]
        lab_test.save!

        ack = ResultsAcknwoledge.find_by(
          tracking_number: order.tracking_number,
          test_id: lab_test.id,
          acknwoledged_by: params[:acknowledged_by]
        )
        if Config.local_nlims? && ack.nil?
          ResultsAcknwoledge.create!(
            tracking_number: order.tracking_number,
            test_id: lab_test.id,
            acknwoledged_at: Time.new.strftime('%Y%m%d%H%M%S'),
            result_date: params[:date_acknowledged],
            acknwoledged_by: params[:acknowledged_by],
            acknwoledged_to_nlims: false,
            acknowledgment_level: recipient_type.id
          )
        end
        [true, 'test result acknowledged successfully']
      end
    end
  end
end
