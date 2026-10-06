# frozen_string_literal: true

module MahisCouchdb
  # Converts a MaHIS patients_records lab order into the NLiMS v2 order payload.
  class LabOrderMapper
    attr_reader :config, :patient_doc, :order

    def initialize(config, patient_doc, order)
      @config = config
      @patient_doc = patient_doc.with_indifferent_access
      @order = order.with_indifferent_access
    end

    def payload
      {
        patient: patient_payload,
        order: order_payload,
        tests: test_payloads
      }.with_indifferent_access
    end

    def order_request?
      specimen_type&.name.to_s == 'not_specified'
    end

    def tracking_number
      first_present(order[:accession_number], order[:tracking_number])
    end

    def order_uuid
      first_present(
        order[:operation_id],
        order[:offline_id],
        order[:client_operation_id],
        order[:sync_operation_id],
        order[:order_uuid],
        order[:uuid],
        order[:order_id],
        "#{patient_doc[:_id]}:#{tracking_number}"
      )
    end

    def valid?
      tracking_number.present? && test_payloads.any?
    end

    def errors
      messages = []
      messages << 'accession_number missing' if tracking_number.blank?
      messages << 'no matching NLiMS test types found' if test_payloads.empty?
      messages
    end

    private

    def patient_payload
      person = (patient_doc[:personInformation] || {}).with_indifferent_access
      {
        national_patient_id: patient_doc_id,
        first_name: first_present(person[:given_name], patient_doc[:given_name], 'Unknown'),
        last_name: first_present(person[:family_name], patient_doc[:family_name], 'Unknown'),
        gender: first_present(person[:gender], patient_doc[:gender], 'U'),
        date_of_birth: first_present(person[:birthdate], patient_doc[:birthdate], Date.current.to_s),
        address: first_present(person[:current_village], person[:home_village], ''),
        email: '',
        phone_number: first_present(person[:cell_phone_number], patient_doc[:phone_number], '')
      }
    end

    def patient_doc_id
      first_present(patient_doc[:_id], patient_doc[:ID], patient_doc[:nationalID], patient_doc[:patientID])
    end

    def order_payload
      {
        uuid: order_uuid,
        tracking_number:,
        sample_type: {
          name: specimen_type&.name || 'not_specified',
          nlims_code: specimen_type&.nlims_code
        },
        sample_status: { name: order_request? ? 'specimen_not_collected' : 'specimen_collected' },
        order_location: first_present(order[:order_location], patient_doc[:program_name], 'OPD'),
        date_created: order_date,
        priority: first_present(reason_for_test, 'Routine'),
        drawn_by: {
          id: first_present(patient_doc[:provider_id], order[:provider_id], '0'),
          name: first_present(order[:requesting_clinician], patient_doc[:provider_name], 'MaHIS'),
          phone_number: ''
        },
        target_lab: first_present(order[:target_lab], config.facility_name),
        sending_facility: first_present(order[:sending_facility], config.facility_name),
        district: first_present(order[:district], config.district),
        requested_by: first_present(order[:requesting_clinician], 'MaHIS'),
        art_start_date: nil,
        arv_number: first_present(patient_doc.dig(:art_summary, :arv_number), 'N/A'),
        art_regimen: first_present(patient_doc.dig(:art_summary, :current_regimen), 'N/A'),
        clinical_history: order[:comment_to_fulfiller],
        lab_location: order[:lab_location],
        source_system: config.source_system
      }.with_indifferent_access
    end

    def test_payloads
      @test_payloads ||= lab_tests.filter_map do |test|
        test = test.with_indifferent_access
        test_type = resolve_test_type(test)
        next unless test_type

        {
          test_type: {
            name: test_type.name,
            nlims_code: test_type.nlims_code,
            method_of_testing: test[:method_of_testing]
          },
          test_uuid: first_present(test[:uuid], test[:test_uuid], "#{order_uuid}:#{test_type.id}")
        }.with_indifferent_access
      end
    end

    def lab_tests
      tests = Array.wrap(order[:tests]).compact
      return tests if tests.any?

      [{ name: order[:name], concept_id: order[:concept_id] }]
    end

    def resolve_test_type(test)
      nlims_code = first_present(test[:nlims_code], test.dig(:test_type, :nlims_code))
      return TestType.find_by(nlims_code:) if nlims_code.present?

      name = first_present(test[:name], test[:test_name], test[:test], test.dig(:test_type, :name))
      return if name.blank?

      normalized = normalize_name(name)
      TestType.where('LOWER(name) = ? OR LOWER(preferred_name) = ?', normalized, normalized).first ||
        TestType.where('LOWER(name) LIKE ? OR LOWER(preferred_name) LIKE ?', "%#{normalized}%", "%#{normalized}%").first
    end

    def specimen_type
      @specimen_type ||= begin
        specimen = order[:specimen]
        specimen_hash = specimen.respond_to?(:with_indifferent_access) ? specimen.with_indifferent_access : {}
        specimen_name = specimen.is_a?(String) ? specimen : specimen_hash[:name]
        nlims_code = first_present(order[:specimen_nlims_code], specimen_hash[:nlims_code])
        resolved = SpecimenType.find_by(nlims_code:) if nlims_code.present?
        resolved ||= resolve_specimen_type_by_name(first_present(specimen_name, order[:specimen_type], order[:sample_type]))
        resolved || SpecimenType.find_by(name: 'not_specified')
      end
    end

    def resolve_specimen_type_by_name(name)
      return if name.blank?

      normalized = normalize_name(name)
      SpecimenType.where('LOWER(name) = ? OR LOWER(preferred_name) = ?', normalized, normalized).first ||
        SpecimenType.where('LOWER(name) LIKE ? OR LOWER(preferred_name) LIKE ?', "%#{normalized}%", "%#{normalized}%").first
    end

    def reason_for_test
      reason = order[:reason_for_test]
      return reason[:name] if reason.respond_to?(:[]) && reason[:name].present?

      first_present(order[:reason], reason)
    end

    def order_date
      value = first_present(order[:order_date], order[:date], patient_doc[:encounter_datetime], Time.current)
      parsed = value.is_a?(Time) || value.is_a?(Date) || value.is_a?(DateTime) ? value : Time.zone.parse(value.to_s)
      parsed.strftime('%Y-%m-%d %H:%M:%S')
    rescue StandardError
      Time.current.strftime('%Y-%m-%d %H:%M:%S')
    end

    def normalize_name(value)
      value.to_s.strip.downcase
    end

    def first_present(*values)
      values.find { |value| value.present? }
    end
  end
end
