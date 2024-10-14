# frozen_string_literal: true

def vl_results(from, to)
  Speciman.find_by_sql <<~SQL
    SELECT 
      s.tracking_number,
      s.sending_facility,
      s.district,
      tr.result,
      s.date_created,
      tr.time_entered,
      tr.created_at
    FROM
      specimen s
          INNER JOIN
      tests t ON t.specimen_id = s.id
          INNER JOIN
      test_results tr ON t.id = tr.test_id
    WHERE
      t.test_type_id = 71 AND
      DATE(s.date_created) BETWEEN '#{from}' AND '#{to}'
  SQL
end

def export_vl_results_to_csv(tracking_number, sending_facility, district, result, date_created, time_entered, created_at)
  file_path = "public/#{Date.today}_vl_results.csv"
  if File.exists?(file_path)
    CSV.open(file_path, 'a') do |csv|
      csv << [tracking_number, sending_facility, district, result, date_created, time_entered, created_at]
    end
  else
    CSV.open(file_path, 'w') do |csv|
      csv << ['Tracking Number', 'Sending Facility', 'District', 'Results', 'Date Order Created', 'Time Result Entered In UMB System', 'Time Result Entered NLIMS CHSU']
      csv << [tracking_number, sending_facility, district, result, date_created, time_entered, created_at]
    end
  end
end

from = '2023-10-01'
to = Date.today
vl_results = vl_results(from, to)
count = vl_results.length
puts count
vl_results.each do |vl_result|
  puts "Exporting results for #{vl_result.tracking_number} to csv"
  export_vl_results_to_csv(
    vl_result.tracking_number,
    vl_result.sending_facility,
    vl_result.district,
    vl_result.result,
    vl_result.date_created,
    vl_result.time_entered,
    vl_result.created_at
  )
  count = count - 1
  puts "Remaining results to export: #{count} \n\n"
end