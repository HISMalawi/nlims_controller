# frozen_string_literal: true
require 'roo'

module TestCatalogService
  def self.create_test_type(params)
    ActiveRecord::Base.transaction do
      @test_type = TestType.create!(params[:test_type])
      @test_type.specimen_types = SpecimenType.where(id: params[:specimen_types])
      @test_type.measures = update_test_measures(params)
      @test_type.organisms = Organism.where(id: params[:organisms])
      @test_type.lab_test_sites = LabTestSite.where(id: params[:lab_test_sites])
      @test_type.equipment = Equipment.where(id: params[:equipment])
    end
    @test_type
  end

  def self.create_test_indicator(params)
    Measure.create!(params[:measures])
  end

  def self.create_organism(params)
    Organism.create!(params[:organisms])
  end

  def self.create_specimen_type(params)
    SpecimenType.create!(params[:specimen_types])
  end

  def self.create_drug(params)
    Drug.create!(params[:drugs])
  end

  def self.get_test_types(params)
    if params[:search]
      TestType.where("name LIKE '%#{params[:search]}%'")
    else
      TestType.all
    end
  end

  def self.update_test_type(test_type, params)
    ActiveRecord::Base.transaction do
      @test_type = test_type
      @test_type.update!(params[:test_type])
      @test_type.update_columns(nlims_code: @test_type.nlims_code || "NLIMS_TT_#{@test_type.id.to_s.rjust(4, '0')}_MWI")
      @test_type.specimen_types = SpecimenType.where(id: params[:specimen_types])
      @test_type.measures = update_test_measures(params)
      @test_type.organisms = Organism.where(id: params[:organisms])
      @test_type.lab_test_sites = LabTestSite.where(id: params[:lab_test_sites])
      @test_type.equipment = Equipment.where(id: params[:equipment])
    end
    @test_type
  end

  def self.import(file)
    results = {
      test_types: {
        total: 0,
        created: 0,
        skipped: 0,
        failed: 0,
        created_names: [],
        skipped_names: [],
        errors: []
      },
      measures: {
        total: 0,
        created: 0,
        skipped: 0,
        failed: 0,
        errors: []
      }
    }

    begin
      # Check file extension - only allow Excel files
      extension = File.extname(file.original_filename).downcase
      unless ['.xlsx', '.xls', '.ods'].include?(extension)
        return {
          success: false,
          error: "Only Excel files (.xlsx, .xls, .ods) are supported. Got: #{extension}"
        }
      end

      # Open Excel file
      spreadsheet = nil
      excel_formats = [
        { extension: :xlsx, name: 'Office Open XML' },
        { extension: :xls, name: 'Excel 97-2003' },
        { extension: :ods, name: 'OpenDocument' }
      ]

      # Try each Excel format until one works
      excel_formats.each do |format|
        begin
          spreadsheet = Roo::Spreadsheet.open(file.path, extension: format[:extension])
          Rails.logger.info("Successfully opened file as #{format[:name]} format")
          break
        rescue => e
          Rails.logger.debug("Failed to open as #{format[:name]}: #{e.message}")
          next
        end
      end

      # If all specific formats fail, try auto-detection
      if spreadsheet.nil?
        begin
          spreadsheet = Roo::Spreadsheet.open(file.path)
          Rails.logger.info("Successfully opened file with auto-detection")
        rescue => e
          return {
            success: false,
            error: "Could not open Excel file: #{e.message}"
          }
        end
      end

      # Process sheets
      sheets_processed = false

      # Check for specific sheet names first
      if spreadsheet.sheets.include?("Test Types")
        process_test_types_sheet(spreadsheet, results)
        sheets_processed = true
      end

      if spreadsheet.sheets.include?("Test Type Measures")
        process_test_measures_sheet(spreadsheet, results)
        sheets_processed = true
      end

      # If no specific sheets found, process the first sheet intelligently
      unless sheets_processed
        if spreadsheet.sheets.any?
          first_sheet = spreadsheet.sheet(spreadsheet.sheets.first)
          headers = first_sheet.row(1)&.map(&:to_s)&.map(&:strip)

          # Determine what type of sheet this is based on headers
          if headers&.include?('TEST TYPE') && headers&.include?('NAME')
            # This looks like a measures sheet
            process_test_measures_sheet_with_sheet(first_sheet, results)
          elsif headers&.include?('NAME') && headers&.include?('TEST CATEGORY/DEPARTMENT')
            # This looks like a test types sheet
            process_test_types_with_sheet(first_sheet, results)
          else
            # Default to test types processing
            process_test_types_with_sheet(first_sheet, results)
          end
        end
      end

    rescue => e
      Rails.logger.error("Import error: #{e.message}\n#{e.backtrace.join("\n")}")
      return {
        success: false,
        error: "Error processing file: #{e.message}",
        details: e.backtrace.first(5)
      }
    end

    {
      success: true,
      summary: results
    }
  end

  def self.update_test_measures(params)
    measure_params = params[:measures] || []
    measure_ids = measure_params.map { |m| m[:id] }.compact
    existing_measures = Measure.where(id: measure_ids).index_by(&:id)
    measures = []
    measure_params.map do |measure_data|
      measure = existing_measures[measure_data[:id]]
      update_measure_ranges(measure, measure_data[:measure_ranges_attributes]) if measure.present?
    end
    measure_params.map do |measure_data|
      measure_record = if measure_data[:id].present?
                          measure = existing_measures[measure_data[:id]]
                          measure.update!(measure_data.except(:measure_ranges_attributes))
                          measure.update_columns(nlims_code: measure.nlims_code || "NLIMS_TI_#{measure.id.to_s.rjust(4,
                                                                                                                     '0')}_MWI")
                          measure.measure_ranges.create!(measure_data[:measure_ranges_attributes])
                          measure
                       else
                          Measure.create!(measure_data)
                       end
      measures << measure_record&.id
    end
    Measure.where(id: measures)
  end

  def self.update_measure_ranges(measure, measure_ranges_params)
    measure_ranges_ids = measure_ranges_params.map { |m| m[:id] }.compact
    measure.measure_ranges.where.not(id: measure_ranges_ids).destroy_all
  end

  def self.get_test_catalog
    {
      specimen_types: SpecimenType.all.as_json({ context: :single_item }),
      drugs: Drug.all.as_json,
      organisms: Organism.all.as_json({ context: :single_item }),
      test_types: TestType.all.as_json({ context: :single_item }),
      test_panels: PanelType.all.as_json
    }
  end

  def self.approve_test_catalog(version_details)
    TestCatalogVersion.create!(
      catalog: get_test_catalog,
      creator: User.current&.id,
      version_details:
    )
  end

  def self.retrieve_test_catalog(version)
    return TestCatalogVersion.find_by(version:) if version.present?

    TestCatalogVersion.last || {}
  end

  def self.test_catalog_versions
    TestCatalogVersion.all.select(:id, :version, :created_at).order(created_at: :desc)
  end

  def self.new_version_available?(previous_version)
    catalog_version = TestCatalogVersion.order(version: :desc)
    latest_version = catalog_version.pick(:version)
    version_details = catalog_version.pick(:version_details)
    return { is_new_version_available: false, version: latest_version } unless latest_version.present?

    {
      is_new_version_available: latest_version > previous_version,
      version: latest_version,
      version_details: version_details
    }
  end

  def self.process_test_types_sheet(spreadsheet, results)
    sheet = spreadsheet.sheet('Test Types')
    headers = sheet.row(1)

    # Clean and map headers to their column indices
    header_map = {}
    headers.each_with_index do |header, idx|
      if header
        clean_header = header.to_s.strip.upcase
        header_map[clean_header] = idx
      end
    end

    required_headers = ['NAME', 'TEST CATEGORY/DEPARTMENT']
    missing_headers = required_headers - header_map.keys

    if missing_headers.any?
      results[:test_types][:errors] << {
        error: "Missing required headers in Test Types sheet: #{missing_headers.join(', ')}. Found headers: #{header_map.keys.join(', ')}"
      }
      return
    end

    Rails.logger.info("Processing Test Types sheet with #{sheet.last_row - 1} rows")

    (2..sheet.last_row).each do |row_idx|
      row = sheet.row(row_idx)
      results[:test_types][:total] += 1

      test_name = row[header_map['NAME']]&.to_s&.strip

      if test_name.blank?
        results[:test_types][:errors] << {
          row: row_idx,
          test_name: "Empty",
          error: "Test name is required"
        }
        results[:test_types][:failed] += 1
        next
      end

      if TestType.exists?(name: test_name)
        results[:test_types][:skipped] += 1
        results[:test_types][:skipped_names] << test_name
        next
      end

      begin
        ActiveRecord::Base.transaction do
          test_category_name = row[header_map['TEST CATEGORY/DEPARTMENT']]&.to_s&.strip
          if test_category_name.blank?
            raise "Test category/department is required"
          end

          test_category = TestCategory.find_or_create_by!(name: test_category_name)

          test_type = TestType.new(
            name: test_name,
            short_name: header_map['SHORT NAME'] ? row[header_map['SHORT NAME']]&.to_s&.strip : nil,
            description: header_map['DESCRIPTION'] ? row[header_map['DESCRIPTION']]&.to_s&.strip : nil,
            preferred_name: header_map['PREFERRED NAME'] ? row[header_map['PREFERRED NAME']]&.to_s&.strip : nil,
            scientific_name: header_map['SCIENTIFIC NAME'] ? row[header_map['SCIENTIFIC NAME']]&.to_s&.strip : nil,
            can_be_done_on_sex: header_map['CAN BE DONE ON SEX'] ? row[header_map['CAN BE DONE ON SEX']]&.to_s&.strip : nil,
            targetTAT: header_map['TARGET TURN AROUND TIME'] ? row[header_map['TARGET TURN AROUND TIME']]&.to_s&.strip : nil,
            test_category_id: test_category.id
          )

          test_type.save!
          test_type.update_columns(nlims_code: "NLIMS_TT_#{test_type.id.to_s.rjust(4, '0')}_MWI")

          if header_map['SPECIMEN TYPES'] && row[header_map['SPECIMEN TYPES']]&.to_s&.strip.present?
            specimen_types = row[header_map['SPECIMEN TYPES']].to_s.split(',').map(&:strip)
            specimen_types.each do |specimen_name|
              next if specimen_name.blank?
              specimen = SpecimenType.find_or_create_by!(name: specimen_name)
              TesttypeSpecimentype.find_or_create_by!(
                test_type_id: test_type.id,
                specimen_type_id: specimen.id
              )
            end
          end

          if header_map['IS MACHINE ORIENTED'] && row[header_map['IS MACHINE ORIENTED']]&.to_s&.strip.present?
            machine_oriented = ['yes', 'true', '1', 'y'].include?(row[header_map['IS MACHINE ORIENTED']].to_s.strip.downcase)
            test_type.update_columns(machine_oriented: machine_oriented)
          end

          if header_map['ASSAY FORMATEQ'] && row[header_map['ASSAY FORMATEQ']]&.to_s&.strip.present?
            test_type.update_columns(assay_format: row[header_map['ASSAY FORMATEQ']]&.to_s&.strip)
          end

          if header_map['LABORATORY LEVEL'] && row[header_map['LABORATORY LEVEL']]&.to_s&.strip.present?
            lab_levels = row[header_map['LABORATORY LEVEL']].to_s.split(',').map(&:strip)
            lab_levels.each do |lab_level|
              next if lab_level.blank?
              lab_site = LabTestSite.find_or_create_by!(name: lab_level)
              TestTypeLabTestSite.find_or_create_by!(
                test_type_id: test_type.id,
                lab_test_site_id: lab_site.id
              )
            end
          end

          Rails.logger.info("Successfully created test type: #{test_name}")
        end

        results[:test_types][:created] += 1
        results[:test_types][:created_names] << test_name
      rescue => e
        results[:test_types][:failed] += 1
        results[:test_types][:errors] << {
          row: row_idx,
          test_name: test_name,
          error: e.message
        }
        Rails.logger.error("Failed to create test type #{test_name}: #{e.message}")
      end
    end
  end

  def self.process_test_types_with_sheet(sheet, results)
    headers = sheet.row(1)

    # Clean and map headers to their column indices
    header_map = {}
    headers.each_with_index do |header, idx|
      if header
        clean_header = header.to_s.strip.upcase
        header_map[clean_header] = idx
      end
    end

    required_headers = ['NAME', 'TEST CATEGORY/DEPARTMENT']
    missing_headers = required_headers - header_map.keys

    if missing_headers.any?
      results[:test_types][:errors] << {
        error: "Missing required headers in sheet: #{missing_headers.join(', ')}. Found headers: #{header_map.keys.join(', ')}"
      }
      return
    end

    Rails.logger.info("Processing test types with #{sheet.last_row - 1} rows")

    (2..sheet.last_row).each do |row_idx|
      row = sheet.row(row_idx)
      results[:test_types][:total] += 1

      test_name = row[header_map['NAME']]&.to_s&.strip

      if test_name.blank?
        results[:test_types][:errors] << {
          row: row_idx,
          test_name: "Empty",
          error: "Test name is required"
        }
        results[:test_types][:failed] += 1
        next
      end

      if TestType.exists?(name: test_name)
        results[:test_types][:skipped] += 1
        results[:test_types][:skipped_names] << test_name
        next
      end

      begin
        ActiveRecord::Base.transaction do
          test_category_name = row[header_map['TEST CATEGORY/DEPARTMENT']]&.to_s&.strip
          if test_category_name.blank?
            raise "Test category/department is required"
          end

          test_category = TestCategory.find_or_create_by!(name: test_category_name)

          test_type = TestType.new(
            name: test_name,
            short_name: header_map['SHORT NAME'] ? row[header_map['SHORT NAME']]&.to_s&.strip : nil,
            description: header_map['DESCRIPTION'] ? row[header_map['DESCRIPTION']]&.to_s&.strip : nil,
            preferred_name: header_map['PREFERRED NAME'] ? row[header_map['PREFERRED NAME']]&.to_s&.strip : nil,
            scientific_name: header_map['SCIENTIFIC NAME'] ? row[header_map['SCIENTIFIC NAME']]&.to_s&.strip : nil,
            can_be_done_on_sex: header_map['CAN BE DONE ON SEX'] ? row[header_map['CAN BE DONE ON SEX']]&.to_s&.strip : nil,
            targetTAT: header_map['TARGET TURN AROUND TIME'] ? row[header_map['TARGET TURN AROUND TIME']]&.to_s&.strip : nil,
            test_category_id: test_category.id
          )

          test_type.save!
          test_type.update_columns(nlims_code: "NLIMS_TT_#{test_type.id.to_s.rjust(4, '0')}_MWI")

          if header_map['SPECIMEN TYPES'] && row[header_map['SPECIMEN TYPES']]&.to_s&.strip.present?
            specimen_types = row[header_map['SPECIMEN TYPES']].to_s.split(',').map(&:strip)
            specimen_types.each do |specimen_name|
              next if specimen_name.blank?
              specimen = SpecimenType.find_or_create_by!(name: specimen_name)
              TesttypeSpecimentype.find_or_create_by!(
                test_type_id: test_type.id,
                specimen_type_id: specimen.id
              )
            end
          end

          if header_map['IS MACHINE ORIENTED'] && row[header_map['IS MACHINE ORIENTED']]&.to_s&.strip.present?
            machine_oriented = ['yes', 'true', '1', 'y'].include?(row[header_map['IS MACHINE ORIENTED']].to_s.strip.downcase)
            test_type.update_columns(machine_oriented: machine_oriented)
          end

          if header_map['ASSAY FORMATEQ'] && row[header_map['ASSAY FORMATEQ']]&.to_s&.strip.present?
            test_type.update_columns(assay_format: row[header_map['ASSAY FORMATEQ']]&.to_s&.strip)
          end

          if header_map['LABORATORY LEVEL'] && row[header_map['LABORATORY LEVEL']]&.to_s&.strip.present?
            lab_levels = row[header_map['LABORATORY LEVEL']].to_s.split(',').map(&:strip)
            lab_levels.each do |lab_level|
              next if lab_level.blank?
              lab_site = LabTestSite.find_or_create_by!(name: lab_level)
              TestTypeLabTestSite.find_or_create_by!(
                test_type_id: test_type.id,
                lab_test_site_id: lab_site.id
              )
            end
          end

          Rails.logger.info("Successfully created test type: #{test_name}")
        end

        results[:test_types][:created] += 1
        results[:test_types][:created_names] << test_name
      rescue => e
        results[:test_types][:failed] += 1
        results[:test_types][:errors] << {
          row: row_idx,
          test_name: test_name,
          error: e.message
        }
        Rails.logger.error("Failed to create test type #{test_name}: #{e.message}")
      end
    end
  end

  # Process Test Type Measures sheet with a given sheet object
  def self.process_test_measures_sheet_with_sheet(sheet, results)
    headers = sheet.row(1)

    # Clean and map headers to their column indices
    header_map = {}
    headers.each_with_index do |header, idx|
      if header
        clean_header = header.to_s.strip.upcase
        header_map[clean_header] = idx
      end
    end

    required_headers = ['TEST TYPE', 'NAME', 'MEASURE TYPE']
    missing_headers = required_headers - header_map.keys

    if missing_headers.any?
      results[:measures][:errors] << {
        error: "Missing required headers in sheet: #{missing_headers.join(', ')}. Found headers: #{header_map.keys.join(', ')}"
      }
      return
    end

    Rails.logger.info("Processing Test Type Measures with #{sheet.last_row - 1} rows")

    # Process each row starting from row 2 (1-indexed, so row 2 is the first data row)
    (2..sheet.last_row).each do |row_idx|
      row = sheet.row(row_idx)
      results[:measures][:total] += 1

      test_type_name = row[header_map['TEST TYPE']]&.to_s&.strip
      measure_name = row[header_map['NAME']]&.to_s&.strip

      if test_type_name.blank? || measure_name.blank?
        results[:measures][:errors] << {
          row: row_idx,
          test_type: test_type_name || "Empty",
          measure_name: measure_name || "Empty",
          error: "Test type and measure name are required"
        }
        results[:measures][:failed] += 1
        next
      end

      begin
        ActiveRecord::Base.transaction do
          # Find the test type
          test_type = TestType.find_by(name: test_type_name)

          unless test_type
            raise "Test type '#{test_type_name}' not found"
          end

          # Get measure type
          measure_type_name = row[header_map['MEASURE TYPE']]&.to_s&.strip || 'Numeric'
          measure_type = MeasureType.find_or_create_by!(name: measure_type_name)

          measure_attributes = {
            name: measure_name,
            measure_type_id: measure_type.id
          }

          # Add optional fields if they exist
          measure_attributes[:short_name] = row[header_map['SHORT NAME']]&.to_s&.strip if header_map['SHORT NAME']
          measure_attributes[:preferred_name] = row[header_map['PREFERRED NAME']]&.to_s&.strip if header_map['PREFERRED NAME']
          measure_attributes[:scientific_name] = row[header_map['SCIENTIFIC NAME']]&.to_s&.strip if header_map['SCIENTIFIC NAME']
          measure_attributes[:description] = row[header_map['DESCRIPTION']]&.to_s&.strip if header_map['DESCRIPTION']
          measure_attributes[:unit] = row[header_map['UNIT']]&.to_s&.strip if header_map['UNIT']

          measure = Measure.find_or_create_by!(name: measure_name, measure_type_id: measure_type.id)

          # Update measure with any additional attributes
          measure.update(measure_attributes)
          measure.update_columns(nlims_code: measure.nlims_code || "NLIMS_TI_#{measure.id.to_s.rjust(4, '0')}_MWI")

          # Associate measure with test type if not already associated
          unless TesttypeMeasure.exists?(test_type_id: test_type.id, measure_id: measure.id)
            TesttypeMeasure.create!(test_type_id: test_type.id, measure_id: measure.id)
          end

          # Create measure range if range data is provided
          if (header_map['MIN AGE'] || header_map['MAX AGE'] || header_map['LOWER RANGE'] ||
              header_map['UPPER RANGE'] || header_map['SEX'] || header_map['VALUE'])

            range_attributes = {}

            range_attributes[:age_min] = row[header_map['MIN AGE']].to_i if header_map['MIN AGE'] && !row[header_map['MIN AGE']].nil?
            range_attributes[:age_max] = row[header_map['MAX AGE']].to_i if header_map['MAX AGE'] && !row[header_map['MAX AGE']].nil?
            range_attributes[:range_lower] = row[header_map['LOWER RANGE']]&.to_s&.strip if header_map['LOWER RANGE'] && row[header_map['LOWER RANGE']]
            range_attributes[:range_upper] = row[header_map['UPPER RANGE']]&.to_s&.strip if header_map['UPPER RANGE'] && row[header_map['UPPER RANGE']]
            range_attributes[:sex] = row[header_map['SEX']]&.to_s&.strip if header_map['SEX'] && row[header_map['SEX']]
            range_attributes[:value] = row[header_map['VALUE']]&.to_s&.strip if header_map['VALUE'] && row[header_map['VALUE']]

            # Create the measure range only if we have range data
            if range_attributes.present?
              range_attributes[:measures_id] = measure.id
              MeasureRange.create!(range_attributes)
            end
          end

          Rails.logger.info("Successfully created/updated measure: #{measure_name} for test type: #{test_type_name}")
        end

        results[:measures][:created] += 1
      rescue => e
        results[:measures][:failed] += 1
        results[:measures][:errors] << {
          row: row_idx,
          test_type: test_type_name,
          measure_name: measure_name,
          error: e.message
        }
        Rails.logger.error("Failed to create measure #{measure_name} for test type #{test_type_name}: #{e.message}")
      end
    end
  end

  def self.process_test_measures_sheet(spreadsheet, results)
    sheet = spreadsheet.sheet('Test Type Measures')
    process_test_measures_sheet_with_sheet(sheet, results)
  end
end
