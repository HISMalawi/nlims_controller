# frozen_string_literal: true

require 'order_service'

specimens = Speciman.find_by_sql(
  "SELECT
    st.name AS specimen_type, s.couch_id, s.target_lab, s.id
  FROM
    specimen s
  INNER JOIN
    specimen_types st ON st.id = s.specimen_type_id
  WHERE
    DATE(date_created) > '2023-10-31'"
)

specimens.each do |specimen|
  target_lab = specimen.target_lab
  couch_id = specimen.couch_id
  if target_lab == 'not_assigned'
    target_lab = 'Kamuzu Central Hospital'
    Speciman.find(specimen.id).update(target_lab: target_lab)
  end
  puts "Updating couch order for couch order id: #{couch_id}"
  couch_order = OrderService.retrieve_order_from_couch(couch_id)
  next if couch_order == 'false'

  couch_order['sample_type'] = specimen.specimen_type
  couch_order['receiving_facility'] = target_lab
  OrderService.update_couch_order(couch_id, couch_order)
  puts 'Order updated'
end
