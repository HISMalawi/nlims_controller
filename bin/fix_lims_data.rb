@fc_code = YAML.load_file("#{Rails.root}/config/application.yml", aliases: true)['facility_code']
@couchdb = YAML.load_file("#{Rails.root}/config/couchdb.yml", aliases: true)['development']

@url = @couchdb['protocol'] + '://' + @couchdb['host'] \
      + ':' + @couchdb['port'].to_s + '/' + @couchdb['prefix'] \
      + '_order_' + @couchdb['suffix']


puts 'Please enter the path to BHT-EMR-API Format/Default: /var/www/BHT-EMR-API'

@bht_emr_path = gets.chomp

@art_db = unless @bht_emr_path.blank?
  YAML.load_file("#{@bht_emr_path}/config/database.yml", aliases: true)
else
  YAML.load_file("/var/www/BHT-EMR-API/config/database.yml", aliases: true)
end

def update_art(acc_num)
  updated_ac_num = 'X' + @fc_code + acc_num[4..(acc_num.length)]

if acc_num != updated_ac_num
  ActiveRecord::Base.connection.execute <<~SQL
  UPDATE #{@art_db['development']['database']}.orders
  SET accession_number = '#{updated_ac_num}'
  WHERE accession_number = '#{acc_num}'
SQL
else
end

end

def update_lims(acc_num)
  updated_ac_num = 'X' + @fc_code + acc_num[4..(acc_num.length)]
  spec = Speciman.find_by(tracking_number: acc_num)

  if spec
	  spec.update(tracking_number: updated_ac_num)
      couchdb_doc = `curl -XGET #{@url}/#{spec.couch_id}`
	  couchdb_doc = JSON.parse(couchdb_doc)
	  if couchdb_doc['tracking_number'] != updated_ac_num
		  couchdb_doc['tracking_number'] = updated_ac_num

		  response = `curl -XPUT #{@url}/#{spec.couch_id} -d '#{couchdb_doc.to_json}'`
	  end
  else
  end
end

def update_couchdb_test_result_date(accession_number)
  results = ActiveRecord::Base.connection.select_all <<~SQL
    SELECT distinct tracking_number,couch_id,time_entered
    FROM specimen INNER JOIN tests ON tests.specimen_id = specimen.id
    INNER JOIN test_results ON test_results.test_id = tests.id
    INNER JOIN measures ON measures.id = test_results.measure_id
    WHERE specimen.tracking_number  = '#{accession_number}';
  SQL

  results.each do |result|
    couchdb_doc = `curl -XGET #{@url}/#{result['couch_id']}`
    couchdb_doc = JSON.parse(couchdb_doc)
    unless couchdb_doc.blank?
      (couchdb_doc['test_results'] || []).each do |key, value|
            value['date_result_entered'] = result['time_entered']
            `curl -XPUT #{@url}/#{result['couch_id']} -d '#{couchdb_doc.to_json}'`
      end
    end
  end
end

tracking_numbers = ActiveRecord::Base.connection.select_all <<~SQL
  SELECT accession_number
  FROM #{@art_db['development']['database']}.orders
  WHERE accession_number is not NULL;
SQL
puts "Adding index"
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE #{@art_db['development']['database']}.orders
  ADD INDEX(accession_number);
SQL

ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE #{@art_db['development']['database']}.orders
  ADD INDEX(accession_number);
SQL

Parallel.each(tracking_numbers, progress: 'Processing Sitecode Updates') do |num|
  update_art(num['accession_number'])
  update_lims(num['accession_number'])
end

ActiveRecord::Base.connection.reconnect!

tracking_numbers = ActiveRecord::Base.connection.select_all <<~SQL
  SELECT accession_number
  FROM #{@art_db['development']['database']}.orders
  WHERE accession_number is not NULL;
SQL

Parallel.each(tracking_numbers, progress: 'Processing Result Date update') do |num|
   update_couchdb_test_result_date(num['accession_number'])
end
