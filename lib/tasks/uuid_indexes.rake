# frozen_string_literal: true

namespace :uuid do
  desc 'Add UUID indexes to all tables'
  task add_indexes: :environment do
    puts "\nAdding UUID indexes..."
    puts '=' * 80
    puts 'This will add indexes using ALGORITHM=INPLACE (online DDL)'
    puts 'Estimated time: 10-30 minutes per 10M records'
    puts '=' * 80

    connection = ActiveRecord::Base.connection

    # Define indexes to add
    indexes = [
      # Primary UUID indexes (unique)
      { table: :tests, column: :uuid, unique: true },
      { table: :specimen_status_trails, column: :uuid, unique: true },
      { table: :test_status_trails, column: :uuid, unique: true },
      { table: :test_results, column: :uuid, unique: true },

      # Foreign key UUID indexes (non-unique)
      { table: :tests, column: :order_uuid, unique: false },
      { table: :specimen_status_trails, column: :order_uuid, unique: false },
      { table: :test_status_trails, column: :test_uuid, unique: false },
      { table: :test_results, column: :test_uuid, unique: false }
    ]

    indexes.each do |index_def|
      table = index_def[:table]
      column = index_def[:column]
      unique = index_def[:unique]

      index_name = "index_#{table}_on_#{column}"

      # Check if index already exists
      if connection.index_exists?(table, column, name: index_name)
        puts "  ⏭️  Index #{index_name} already exists, skipping..."
        next
      end

      print "  Adding index on #{table}.#{column}#{unique ? ' (unique)' : ''}... "
      start_time = Time.now

      begin
        # Use raw SQL to specify ALGORITHM=INPLACE
        unique_clause = unique ? 'UNIQUE' : ''
        connection.execute(
          "CREATE #{unique_clause} INDEX #{index_name} ON #{table} (#{column}) ALGORITHM=INPLACE"
        )

        elapsed = (Time.now - start_time).round(2)
        puts "✓ (#{elapsed}s)"
      rescue StandardError => e
        puts "❌ Error: #{e.message}"
      end
    end

    puts "\n" + '=' * 80
    puts '✓ Index creation complete!'
    puts "\nNext steps:"
    puts '1. Verify indexes: SHOW INDEX FROM tests WHERE Key_name LIKE \'%uuid%\';'
    puts '2. Continue with UUID backfill or NOT NULL constraints as needed'
    puts '=' * 80
  end

  desc 'Remove UUID indexes (rollback)'
  task remove_indexes: :environment do
    puts "\nRemoving UUID indexes..."
    puts '=' * 80

    connection = ActiveRecord::Base.connection

    indexes = [
      { table: :tests, column: :uuid },
      { table: :specimen_status_trails, column: :uuid },
      { table: :test_status_trails, column: :uuid },
      { table: :test_results, column: :uuid },
      { table: :tests, column: :order_uuid },
      { table: :specimen_status_trails, column: :order_uuid },
      { table: :test_status_trails, column: :test_uuid },
      { table: :test_results, column: :test_uuid }
    ]

    indexes.each do |index_def|
      table = index_def[:table]
      column = index_def[:column]
      index_name = "index_#{table}_on_#{column}"

      if connection.index_exists?(table, column, name: index_name)
        print "  Removing index on #{table}.#{column}... "
        begin
          connection.remove_index table, name: index_name
          puts '✓'
        rescue StandardError => e
          puts "❌ Error: #{e.message}"
        end
      else
        puts "  ⏭️  Index #{index_name} does not exist, skipping..."
      end
    end

    puts "\n" + '=' * 80
    puts '✓ Index removal complete'
    puts '=' * 80
  end

  desc 'List UUID indexes'
  task list_indexes: :environment do
    puts "\nUUID Indexes Status"
    puts '=' * 80

    connection = ActiveRecord::Base.connection

    tables = %i[tests specimen_status_trails test_status_trails test_results]
    uuid_columns = {
      tests: %i[uuid order_uuid],
      specimen_status_trails: %i[uuid order_uuid],
      test_status_trails: %i[uuid test_uuid],
      test_results: %i[uuid test_uuid]
    }

    tables.each do |table|
      puts "\n#{table.to_s.upcase}:"
      uuid_columns[table].each do |column|
        index_name = "index_#{table}_on_#{column}"
        if connection.index_exists?(table, column, name: index_name)
          index_info = connection.indexes(table).find { |idx| idx.name == index_name }
          unique_status = index_info&.unique ? '(unique)' : ''
          puts "  ✓ #{column} #{unique_status}"
        else
          puts "  ✗ #{column} - NO INDEX"
        end
      end
    end

    puts "\n" + '=' * 80
  end

  desc 'Verify UUID columns exist'
  task verify_columns: :environment do
    puts "\nVerifying UUID Columns"
    puts '=' * 80

    connection = ActiveRecord::Base.connection

    expected_columns = {
      'tests' => %w[uuid order_uuid],
      'specimen_status_trails' => %w[uuid order_uuid],
      'test_status_trails' => %w[uuid test_uuid],
      'test_results' => %w[uuid test_uuid]
    }

    all_columns_exist = true

    expected_columns.each do |table, columns|
      puts "\n#{table.upcase}:"
      columns.each do |column|
        if connection.column_exists?(table.to_sym, column.to_sym)
          puts "  ✓ #{column}"
        else
          puts "  ✗ #{column} - MISSING"
          all_columns_exist = false
        end
      end
    end

    puts "\n" + '=' * 80
    if all_columns_exist
      puts '✓ All UUID columns exist'
    else
      puts '❌ Some UUID columns are missing. Run: rails db:migrate'
    end
    puts '=' * 80
  end
end
