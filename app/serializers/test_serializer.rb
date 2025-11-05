# frozen_string_literal: true

# TestSerializer class for serializing tests
module TestSerializer
  class << self
    def serialize(test)
      {
        tracking_number: test&.speciman&.tracking_number,
        arv_number:test&.speciman&.arv_number,
        uuid: test&.speciman&.couch_id,
        test_status: test&.test_status&.name,
        time_updated: test&.test_status_trail&.where(test_status_id: test&.test_status_id)&.first&.time_updated || test&.updated_at,
        test_type: test&.test_type,
        status_trail: test&.test_status_trail&.map do |trail|
          {
            status_id: trail&.test_status_id,
            status: trail&.test_status&.name,
            timestamp: trail&.time_updated,
            updated_by: {
              first_name: trail&.who_updated_name&.split(' ')&.first,
              last_name: trail&.who_updated_name&.split(' ')&.last,
              id: trail&.who_updated_id,
              phone_number: trail&.who_updated_phone_number
            }
          }
        end,
        test_results: test&.test_results&.where&.not(result: '')&.where&.not(result: nil)&.map do |result|
          {
            measure: {
              name: result&.measure&.name,
              nlims_code: result&.measure&.nlims_code,
              moh_code: result&.measure&.moh_code,
              loinc_code: result&.measure&.loinc_code,
              preferred_name: result&.measure&.preferred_name,
              scientific_name: result&.measure&.scientific_name,
              short_name: result&.measure&.short_name,
              measure_type: result&.measure&.measure_type&.name
            },
            result: {
              value: result&.result,
              unit: result&.unit,
              result_date: result&.time_entered,
              platform: result&.device_name,
              platformserial: ''
            }
          }
        end
      }
    end
  end
end
