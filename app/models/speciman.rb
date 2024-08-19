# frozen_string_literal: true

# Specimen model
class Speciman < ApplicationRecord
  after_create :push_order_to_master_nlims

  def push_order_to_master_nlims
    tests = Test.where(specimen_id: id)
    client = Patient.find_by(id: tests&.first&.patient_id)
    payload = {
      tracking_number:,
      date_sample_drawn: date_created,
      date_received: created_at,
      health_facility_name: sending_facility,
      district:,
      target_lab:,
      requesting_clinician: requested_by,
      return_json: 'true',
      sample_type: SpecimenType.find_by(id: specimen_type_id)&.name,
      tests: TestType.where(id: tests.pluck(:test_type_id)).pluck(:name),
      sample_status: SpecimenStatus.find_by(id: specimen_status_id)&.name,
      sample_priority: priority,
      reason_for_test: priority,
      order_location: Ward.find_by(id: ward_id)&.name,
      who_order_test_id: nil,
      who_order_test_last_name: tests&.first&.created_by&.split(' ')&.last,
      who_order_test_first_name: tests&.first&.created_by&.split(' ')&.first,
      who_order_test_phone_number: '',
      first_name: client.first_name,
      last_name: client.last_name,
      middle_name: client.middle_name,
      date_of_birth: client[:dob],
      gender: client.sex,
      patient_residence: client[:address],
      patient_location: '',
      patient_town: '',
      patient_district: '',
      national_patient_id: client[:patient_number],
      phone_number: client[:phone_number],
      art_start_date:,
      art_regimen:,
      arv_number:
    }
    # response = RestClient::Request.execute(
    #   method: :post,
    #   url: "#{nlims[:base_url]}/api/v1/create_order/",
    #   headers: { content_type: :json, accept: :json, 'token': "#{nlims[:token]}" },
    #   payload: payload.to_json
    # )
  end
end
