# frozen_string_literal: true

# Rake task to dump/load metadata tables to db/sql/metadata
namespace :db do
  desc 'Dump metadata tables to db/sql/metadata using simple mysqldump commands'
  task dump_metadata: :environment do
    db_config = Rails.configuration.database_configuration[Rails.env]
    db_name   = db_config['database']
    db_user   = db_config['username']
    db_pass   = db_config['password']
    db_host   = db_config['host'] || '127.0.0.1'

    tables = %w[
      drugs equipments equipment_test_types lab_test_sites measure_ranges measure_types measures
      organism_drugs organisms panel_types panels product_equipments products specimen_types
      test_catalog_versions test_categories specimen_types test_type_lab_test_sites test_types
      testtype_measures testtype_organisms testtype_specimentypes versions
    ]

    output_dir = Rails.root.join('db/sql/metadata')
    FileUtils.mkdir_p(output_dir)

    tables.each do |table|
      file = output_dir.join("#{table}.sql")
      puts "💾 Dumping #{table}..."
      system("mysqldump -h #{db_host} -u#{db_user} -p#{db_pass} #{db_name} #{table} > #{file}")
    end

    puts "\n✅ All metadata tables dumped to #{output_dir}"
  end

  desc 'Restore metadata tables from db/sql/metadata/*.sql'
  task load_metadata: :environment do
    db_config = Rails.configuration.database_configuration[Rails.env]
    db_name   = db_config['database']
    db_user   = db_config['username']
    db_pass   = db_config['password']
    db_host   = db_config['host'] || '127.0.0.1'

    sql_files = Dir.glob(Rails.root.join('db/sql/metadata/*.sql'))
    if sql_files.empty?
      puts '⚠️  No SQL files found in db/sql/metadata'
      next
    end

    sql_files.each do |file|
      puts "🚀 Loading #{File.basename(file)}..."
      system("mysql -h #{db_host} -u#{db_user} -p#{db_pass} #{db_name} < #{file}")
    end

    puts "\n✅ Metadata restore complete!"
  end
end

