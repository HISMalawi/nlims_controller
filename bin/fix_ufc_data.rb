# frozen_string_literal: true

require 'rest-client'

# Get clients from NLIMS grouped by date and client id with abnormal orders
def client_with_abnormal_orders
  Speciman.find_by_sql <<~SQL
    SELECT
      p.patient_number,
      DATE(s.date_created) date_created,
      COUNT(*) count
    FROM specimen s
      INNER JOIN
    tests t ON t.specimen_id = s.id
      INNER JOIN
    patients p ON p.id = t.patient_id
      WHERE
    t.test_type_id = 71
    GROUP BY DATE(s.date_created) , p.id
    HAVING COUNT(*) > 10
    ORDER BY DATE(s.date_created) DESC
  SQL
end

def orders_with_result_for_specific_client(patient_number, date_created)
  orders = Speciman.find_by_sql <<~SQL
    SELECT
      s.tracking_number
    FROM
      specimen s
          INNER JOIN
      tests t ON t.specimen_id = s.id
          INNER JOIN
      patients p ON p.id = t.patient_id
          INNER JOIN
      test_results tr ON tr.test_id = t.id
    WHERE
      t.patient_id = (SELECT
            ip.id
        FROM
            patients ip
        WHERE
            ip.patient_number = '#{patient_number}'
        LIMIT 1)
        AND t.test_type_id = 71
        AND DATE(s.date_created) = '#{date_created}'
  SQL
  orders.map(&:tracking_number)
end

def order_for_specific_client(patient_number, date_created)
  Speciman.find_by_sql <<~SQL
    SELECT
      s.id,
      t.id AS test_id,
      DATE(s.date_created) AS date_created,
      s.tracking_number,
      s.couch_id,
      p.patient_number
    FROM
      specimen s
          INNER JOIN
      tests t ON t.specimen_id = s.id
          INNER JOIN
      patients p ON p.id = t.patient_id
    WHERE
      t.patient_id = (SELECT
            ip.id
        FROM
            patients ip
        WHERE
            ip.patient_number = '#{patient_number}'
        LIMIT 1
      )
      AND t.test_type_id = 71
      AND DATE(s.date_created) = '#{date_created}'
  SQL
end

def delete_order(order_id)
  order = Speciman.find(order_id)
  order.destroy unless order.nil?
end

def delete_test(test_id)
  test_ = Test.find(test_id)
  test_.destroy unless test_.nil?
end

def record_deleted_order(tracking_number, patient_number, date_created, time_run)
  file_path = 'public/fixed_ufc_data.csv'
  if File.exist?(file_path)
    CSV.open(file_path, 'a') do |csv|
      csv << [tracking_number, patient_number, date_created, time_run]
    end
  else
    CSV.open(file_path, 'w') do |csv|
      csv << ['Tracking Number', 'Patient Number', 'Date Order Created', 'Date Script Run']
      csv << [tracking_number, patient_number, date_created, time_run]
    end
  end
end

clients = client_with_abnormal_orders
clients.each do |client|
  orders_with_results = orders_with_result_for_specific_client(client.patient_number, client.date_created)
  orders_for_client = order_for_specific_client(client.patient_number, client.date_created)
  orders_for_client.each do |order|
    puts "Fixing order #{order.tracking_number} \n\n"
    next if orders_with_results.include?(order.tracking_number)

    ActiveRecord::Base.transaction do
      # delete test associated with order
      delete_test(order.test_id)
      # delete order itself
      delete_order(order.id)
      # Keep track of deleted orders in a file - prior to this, keep dump of the database
      record_deleted_order(order.tracking_number, order.patient_number, order.date_created, Time.now)
    end
  end
end
