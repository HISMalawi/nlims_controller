# frozen_string_literal: true

# OrderSerializer class for serializing orders
module OrderSerializer
  class << self
    def serialize(order)
      {
        order: {
          couch_id: order&.couch_id,
          tracking_number: order&.tracking_number,
          sample_type: order&.specimen_types,
          sample_status: order&.specimen_statuses,
          order_location: order&.wards&.name,
          date_created: order&.date_created,
          priority: order&.priority,
          reason_for_test: order&.priority,
          drawn_by: {
            id: order&.drawn_by_id,
            name: order&.drawn_by_name,
            phone_number: order&.drawn_by_phone_number
          },
          target_lab: order&.target_lab,
          sending_facility: order&.sending_facility,
          site_code_number: Site.find_by(name: order&.sending_facility)&.site_code_number || '',
          requested_by: order&.requested_by,
          district: order&.district,
          art_start_date: order&.art_start_date,
          arv_number: order&.arv_number,
          art_regimen: order&.art_regimen,
          lab_location: order&.lab_location,
          source_system: order&.source_system,
          clinical_history: order&.clinical_history,
          status_trail: order&.specimen_status_trail&.map do |trail|
            {
              status_id: trail&.specimen_status_id,
              status: trail&.specimen_status&.name,
              timestamp: trail&.time_updated,
              updated_by: {
                first_name: trail&.who_updated_name&.split(' ')&.first,
                last_name: trail&.who_updated_name&.split(' ')&.last,
                id: trail&.who_updated_id,
                phone_number: trail&.who_updated_phone_number
              }
            }
          end
        },
        patient: serialize_patient(order&.tests&.first&.patient),
        tests: order.tests.map { |t| TestSerializer.serialize(t) }
      }
    end

    def serialize_patient(patient)
      {
        id: patient&.id,
        national_patient_id: patient&.patient_number,
        first_name: patient&.name&.split(' ')&.first,
        last_name: patient&.name&.split(' ')&.last,
        gender: patient&.gender,
        date_of_birth: patient&.dob,
        address: patient&.address,
        phone_number: patient&.phone_number
      }
    end
  end
end
