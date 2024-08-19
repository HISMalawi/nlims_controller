# frozen_string_literal: true

# Specimen model
class Speciman < ApplicationRecord
  # after_create :push_order_to_master_nlims
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
       order_location: encounter.facility_section.name,
       who_order_test_id: nil,
       who_order_test_last_name: '',
       who_order_test_first_name: '',
       who_order_test_phone_number: '',
       first_name: client[:name].split(' ').first,
       last_name: client[:name].split(' ').last,
       middle_name: client[:name].split(' ').length > 2 ? client[:name].split(' ')[1] : '',
       date_of_birth: client[:date_of_birth],
       gender: client[:sex] == 'F' ? 1 : 0,
       patient_residence: '',
       patient_location: '',
       patient_town: '',
       patient_district: '',
       national_patient_id: '',
       phone_number: '',
       art_start_date:,
       art_regimen:,
       arv_number:
     }
   end
en
