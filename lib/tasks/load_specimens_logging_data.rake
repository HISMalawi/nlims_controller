# frozen_string_literal: true

namespace :tracking_number_loggers do
  desc 'Load tracking numbers from specimens.json or specimens.json.gz file into TrackingNumberLogger table'
  task load_data: :environment do
    require 'json'
    require 'zlib'

    # Check for both compressed and uncompressed files
    json_file = File.join(Rails.root, 'specimens.json')
    gz_file = File.join(Rails.root, 'specimens.json.gz')

    file_path = nil
    if File.exist?(gz_file)
      file_path = gz_file
      puts "Found compressed file: #{gz_file}"
    elsif File.exist?(json_file)
      file_path = json_file
      puts "Found uncompressed file: #{json_file}"
    else
      puts "Error: Neither specimens.json nor specimens.json.gz found in #{Rails.root}"
      exit 1
    end

    puts "Loading specimens data from #{file_path}..."

    # Read and parse the file (handling both compressed and uncompressed)
    begin
      file_content = if file_path.end_with?('.gz')
                       # Read compressed file
                       Zlib::GzipReader.open(file_path) { |gz| gz.read }
                     else
                       # Read regular file
                       File.read(file_path)
                     end

      specimens_data = JSON.parse(file_content)
      total_specimens = specimens_data.size
      puts "Found #{total_specimens} specimens in the file"

      # Get the highest existing chsu_tracking_number_order_id to avoid duplicates
      ActiveRecord::Base.connection.execute("TRUNCATE TABLE tracking_number_loggers")
      last_logged_id = TrackingNumberLogger.maximum(:chsu_tracking_number_order_id) || 0
      puts "Last logged ID in database: #{last_logged_id}"

      # Filter specimens that are not already in the database
      new_specimens = specimens_data.select { |specimen| specimen['id'].to_i > last_logged_id }
      puts "Found #{new_specimens.size} new specimens to import"

      # Process in batches to avoid memory issues
      batch_size = 1000
      total_imported = 0
      batch_count = 0

      new_specimens.each_slice(batch_size) do |batch|
        batch_count += 1
        current_batch_size = batch.size

        # Create an array of TrackingNumberLogger objects
        tracking_loggers = batch.map do |specimen|
          {
            tracking_number: specimen['tracking_number'],
            chsu_tracking_number_order_id: specimen['id'],
            created_at: Time.current,
            updated_at: Time.current
          }
        end

        # Import the batch
        begin
          TrackingNumberLogger.insert_all(tracking_loggers)
          total_imported += current_batch_size

          progress_percentage = (total_imported.to_f / new_specimens.size * 100).round(2)
          puts "Batch #{batch_count}: Imported #{current_batch_size} specimens. " \
               "Total progress: #{total_imported}/#{new_specimens.size} (#{progress_percentage}%)"
        rescue StandardError => e
          puts "Error importing batch #{batch_count}: #{e.message}"
          puts 'Skipping batch and continuing...'
        end
      end

      puts "Import completed. Total specimens imported: #{total_imported}"
    rescue JSON::ParserError => e
      puts "Error parsing JSON file: #{e.message}"
      exit 1
    rescue StandardError => e
      puts "Error during import: #{e.message}"
      puts e.backtrace
      exit 1
    end
  end

  desc 'Check specimens.json or specimens.json.gz file structure'
  task check_file: :environment do
    require 'json'
    require 'zlib'

    # Check for both compressed and uncompressed files
    json_file = File.join(Rails.root, 'specimens.json')
    gz_file = File.join(Rails.root, 'specimens.json.gz')

    file_path = nil
    if File.exist?(gz_file)
      file_path = gz_file
      puts "Found compressed file: #{gz_file}"
    elsif File.exist?(json_file)
      file_path = json_file
      puts "Found uncompressed file: #{json_file}"
    else
      puts "Error: Neither specimens.json nor specimens.json.gz found in #{Rails.root}"
      exit 1
    end

    puts 'Checking file structure...'

    # Read the first few records to check structure
    begin
      # Read a sample from the file
      sample = if file_path.end_with?('.gz')
                 # Read first part of compressed file
                 Zlib::GzipReader.open(file_path) do |gz|
                   gz.read(1000) # Read first 1000 characters after decompression
                 end
               else
                 # Read first 1000 characters from regular file
                 File.open(file_path) { |f| f.read(1000) }
               end

      # Try to parse the sample
      if sample.start_with?('[')
        puts 'File appears to be a JSON array'

        # Parse the full file to validate
        file_content = if file_path.end_with?('.gz')
                         Zlib::GzipReader.open(file_path, &:read)
                       else
                         File.read(file_path)
                       end

        specimens_data = JSON.parse(file_content)

        if specimens_data.is_a?(Array) && !specimens_data.empty?
          sample_record = specimens_data.first
          puts 'Sample record structure:'
          puts JSON.pretty_generate(sample_record)

          # Check if the structure matches what we expect
          if sample_record.key?('id') && sample_record.key?('tracking_number')
            puts 'File structure is valid for import'
            puts "Total records in file: #{specimens_data.size}"
          else
            puts "Warning: Expected keys 'id' and 'tracking_number' not found in sample record"
          end
        else
          puts 'Warning: File does not contain a non-empty array'
        end
      else
        puts "Warning: File does not start with '[', may not be a JSON array"
      end
    rescue JSON::ParserError => e
      puts "Error parsing JSON file: #{e.message}"
    rescue StandardError => e
      puts "Error checking file: #{e.message}"
    end
  end
end
