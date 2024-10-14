# frozen_string_literal: true

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
  if target_lab == 'not_assigned'
    target_lab = 'Kamuzu Central Hospital'
    Speciman.find(specimen.id).update(target_lab:)
  end
end
