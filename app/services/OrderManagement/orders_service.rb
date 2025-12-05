# frozen_string_literal: true

# OrderManagement module
module OrderManagement
  # OrderService class
  class OrdersService
    def self.create_order(params, order_request = false)
      ActiveRecord::Base.transaction do
        params[:tests].each do |tst|
          test_name = TestType.find_by(nlims_code: tst.dig(:test_type, :nlims_code))
          unless test_name.present?
            return [
              false,
              "test name not available in nlims for #{tst.dig(:test_type, :nlims_code)}"
            ]
          end
        end
        specimen_type = if order_request
                          SpecimenType.find_by(name: 'not_specified')
                        else
                          SpecimenType.find_by(nlims_code: params[:order].dig(:sample_type, :nlims_code))
                        end
        if specimen_type.blank?
          return [
            false,
            "specimen type not available in nlims for #{params[:order].dig(:sample_type, :nlims_code)}"
          ]
        end

        if params[:order][:sample_status].present?
          specimen_status = SpecimenStatus.find_by(name: params[:order][:sample_status][:name]&.gsub('-', '_'))
          return [false, 'specimen status not available in nlims'] if specimen_status.blank?
        end

        patient = create_patient(params[:patient])
        specimen = create_specimen(params[:order], order_request)
        Visit.create(
          patient_id: patient.id,
          visit_type_id: '',
          ward_id: Ward.get_ward_id(NameMapping.actual_name_of(params[:order][:order_location]))
        )
        params[:tests].each do |lab_test|
          time_created = params[:order][:date_created] || Date.today
          test_status_id = TestStatus.get_test_status_id('drawn')
          created_by = params[:order][:drawn_by][:name]
          if PanelType.find_by(name: lab_test.dig(:test_type, :name)).blank?
            create_test(
              patient,
              specimen,
              TestType.find_by(nlims_code: lab_test.dig(:test_type, :nlims_code))&.id,
              time_created,
              test_status_id,
              created_by,
              panel_id = nil,
              lab_test.dig(:test_type, :method_of_testing)
            )
          else
            panel = PanelType.find_by(name: lab_test)
            test_types = panel&.test_types || []
            test_types.each do |test_type|
              create_test(
                patient,
                specimen,
                test_type.id,
                time_created,
                test_status_id,
                created_by,
                panel_id = panel.id,
                lab_test.dig(:test_type, :method_of_testing)
              )
            end
          end
        end
      end
      [true, params[:order][:tracking_number]]
    rescue StandardError => e
      [false, e.message]
    end

    def self.update_order(order, params)
      specimen_status = SpecimenStatus.find_by(name: params['status'])
      if specimen_status.blank?
        return [false,
                "specimen status not available in nlims - available statuses are #{SpecimenStatus.all.pluck(:name)}"]
      end

      return [false, 'time updated not provided'] if params['time_updated'].blank?

      state, error_message = validate_time_updated(params['time_updated'], order)
      return [false, error_message] unless state

      return [false, 'status trail not provided'] if params['status_trail'].blank?

      if params['sample_type'].present?
        specimen_type = SpecimenType.find_by(nlims_code: params.dig(:sample_type, :nlims_code))
        return [false, "specimen type not available in nlims for #{params.dig(:sample_type, :nlims_code)}"] if specimen_type.blank?
      end

      ActiveRecord::Base.transaction do
        OrderManagement::SpecimenStatusUpdaterService.call(order, specimen_status)
        if params['sample_type'].present?
          specimen_type = SpecimenType.find_by(nlims_code: params.dig(:sample_type, :nlims_code))
          order.update!(
            specimen_type_id: specimen_type.id,
            specimen_status_id: specimen_status.id
          )
        end
        params[:status_trail].each do |trail|
          trail_status = SpecimenStatus.find_by(name: trail[:status])
          next unless trail_status.present?
          next if SpecimenStatusTrail.exists?(specimen_id: order.id, specimen_status_id: trail_status.id)

          SpecimenStatusTrail.create!(
            specimen_id: order.id,
            time_updated: trail[:timestamp],
            specimen_status_id: trail_status.id,
            who_updated_id: trail[:updated_by]['id'].to_s,
            who_updated_name: "#{trail[:updated_by]['first_name']} #{trail[:updated_by]['last_name']}",
            who_updated_phone_number: trail[:updated_by]['phone_number'].to_s
          )
        end
        [true, '']
      rescue StandardError => e
        Rails.logger.error("Update order failed: #{e.message}")
        [false, "an error occurred while updating the order: #{e.message}"]
      end
    end

    def self.create_patient(params)
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

    def self.create_specimen(params, order_request)
      sample_status_id = SpecimenStatus.get_specimen_status_id(params[:sample_status][:name]&.gsub('-', '_'))
      order_ward = Ward.get_ward_id(NameMapping.actual_name_of(params[:order_location]))
      if order_request
        sample_status_id = SpecimenStatus.get_specimen_status_id('specimen_not_collected')
        specimen_type = SpecimenType.find_by(name: 'not_specified')
      else
        specimen_type = SpecimenType.find_by(nlims_code: params.dig(:sample_type, :nlims_code))
      end
      order = Speciman.create!(
        couch_id: params[:uuid] || SecureRandom.uuid,
        tracking_number: params[:tracking_number],
        specimen_type_id: specimen_type&.id,
        specimen_status_id: sample_status_id,
        ward_id: order_ward,
        date_created: params[:date_created] || Date.today,
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
      )
      if params[:status_trail].present?
        params[:status_trail].each do |trail|
          specimen_status = SpecimenStatus.find_by(name: trail[:status])
          next unless specimen_status.present?
          next if SpecimenStatusTrail.exists?(specimen_id: order.id, specimen_status_id: specimen_status.id)

          SpecimenStatusTrail.create!(
            specimen_id: order.id,
            time_updated: trail[:timestamp],
            specimen_status_id: specimen_status.id,
            who_updated_id: trail[:updated_by]['id'].to_s,
            who_updated_name: "#{trail[:updated_by]['first_name']} #{trail[:updated_by]['last_name']}",
            who_updated_phone_number: trail[:updated_by]['phone_number'].to_s
          )
        end
      end
      order
    end

    def self.create_test(patient, specimen, testype_id, time_created, test_status_id, created_by, panel_id = nil, method_of_testing = nil)
      Test.create!(
        specimen_id: specimen.id,
        test_type_id: testype_id,
        patient_id: patient.id,
        created_by: created_by,
        panel_id: panel_id,
        method_of_testing: method_of_testing,
        time_created: time_created,
        test_status_id: test_status_id
      )
    end

    def self.validate_time_updated(time_updated, order)
      # Only compare if date_created exists and dates are valid
      if order.date_created.present?
        begin
          time_updated_date = time_updated.to_s.to_date
          created_date = order.date_created.to_date
          return [false, 'time updated or result date provided is in the past'] if time_updated_date < created_date
        rescue StandardError
          # Any error (invalid date format, type mismatch, etc.) - just proceed
          [true, nil]
        end
      end
      # Proceed - return success or continue with rest of logic
      [true, nil]
    end

    def self.order_tracking_numbers_to_logged(order_id, limit: 50_000, from: '2022-01-01')
      limit = (limit.to_i > 50_000 ? 50_000 : limit.to_i) || 50_000
      Speciman.where(id: (order_id.to_i).., created_at: from..).order(id: :asc).where.not(id: order_id.to_i)
              .limit(limit).select(:id, :tracking_number)
    end

    def self.order_exist?(tracking_number)
      TrackingNumberLogger.where(tracking_number: tracking_number).exists? ||
        Speciman.where(tracking_number: tracking_number).exists?
    end

    def self.confirm_order_request(params)
      order = Speciman.find_by(tracking_number: params['tracking_number'])
      return [false, 'order not available'] if order.blank?

      specimen_type = SpecimenType.find_by(nlims_code: params.dig(:sample_type, :nlims_code))
      return [false, "specimen type not available in nlims for #{params.dig(:sample_type, :nlims_code)}"] if specimen_type.blank?

      order.update!(
        specimen_type_id: specimen_type.id,
        specimen_status_id: SpecimenStatus.get_specimen_status_id('specimen_collected')
      )
      order.update!(target_lab: params['target_lab']) if params['target_lab'].present?
      [true, 'order confirmed successfully']
    end

    def self.find_all_orders(_params)
      Speciman.find_by_sql("SELECT specimen_types.name AS sample_name, specimen_types.preferred_name AS sample_preferred_name,
                  specimen_types.nlims_code AS sample_nlims_code, specimen.couch_id AS uuid, specimen.tracking_number AS tracking_number,
                  specimen_statuses.name AS specimen_status,
                  wards.name AS order_location, specimen.date_created AS date_created, specimen.priority AS priority,
                  specimen.drawn_by_id AS drawer_id, specimen.drawn_by_name AS drawer_name,
                  specimen.drawn_by_phone_number AS drawe_number, specimen.target_lab AS target_lab,
                  specimen.sending_facility AS health_facility, specimen.requested_by AS requested_by,
                  specimen.date_created AS date_drawn,
                  patients.patient_number AS pat_id, patients.name AS pat_name,
                  patients.dob AS dob, patients.gender AS sex,
                  art_regimen AS art_regi, arv_number AS arv_number,
                  art_start_date AS art_start_date,
                  sites.site_code_number AS site_code_number
                  FROM specimen INNER JOIN specimen_statuses ON specimen_statuses.id = specimen.specimen_status_id
                  LEFT JOIN specimen_types ON specimen_types.id = specimen.specimen_type_id
                  INNER JOIN tests ON tests.specimen_id = specimen.id
                  INNER JOIN patients ON patients.id = tests.patient_id
                  LEFT JOIN wards ON specimen.ward_id = wards.id
                  INNER JOIN test_types ON test_types.id = tests.test_type_id
                  INNER JOIN sites ON sites.name = specimen.sending_facility
            WHERE (DATE(specimen.created_at) BETWEEN '#{date_from}' AND '#{date}')
            AND ((test_types.name ='HIV Viral Load' OR test_types.preferred_name ='Viral Load') AND sites.region='#{region}') ORDER BY specimen.id DESC limit 35000")
    end
  end
end
