# frozen_string_literal: true

require 'order_service'

namespace :nlims do
  desc 'Fix data'
  task update_specimen: :environment do
    params = []
    specimens = Speciman.where(specimen_type_id: 0, date_created: '2023-11-10'...Time.now)
    specimens.each do |specimen|
      tests = Test.where(specimen_id: specimen.id)
      tests.each do |test_|
        test_type = TestType.where(name: 'Viral Load').map(&:id)
        if test_type.include?(test_.id)
          if specimen.tracking_number[0] == 'X'
            params.push(
              {
                specimen_type: 'Plasma',
                target_lab: 'Thyolo District Hospital',
                tracking_number: specimen.tracking_number
              }
            )
          elsif specimen.tracking_number[0] == 'L'
            params.push(
              {
                specimen_type: 'DBS (Free drop to DBS card)',
                target_lab: 'Thyolo District Hospital',
                tracking_number: specimen.tracking_number
              }
            )
          end
        end
      end
    end
    params.each do |param|
      specimen_type = param[:specimen_type]
      target_lab = param[:target_lab]
      st = SpecimenType.find_by_sql("SELECT id AS type_id FROM specimen_types WHERE name='#{specimen_type}'")
      type_id = st[0]['type_id']
      obj = Speciman.find_by(tracking_number: param[:tracking_number])
      couch_id = obj['couch_id']
      obj.specimen_type_id = type_id
      obj.target_lab = target_lab
      obj.specimen_status_id = SpecimenStatus.find_by(name: 'specimen_collected')['id']
      obj.save
      retr_order = OrderService.retrieve_order_from_couch(couch_id)
      next if retr_order == 'false'

      retr_order['sample_type'] = specimen_type
      retr_order['receiving_facility'] = target_lab
      retr_order['sample_status'] = 'specimen_collected'
      OrderService.update_couch_order(couch_id, retr_order)
    end
  end
end
