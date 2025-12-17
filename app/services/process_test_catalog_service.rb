# frozen_string_literal: true

# module ProcessTestCatalog
module ProcessTestCatalogService
  class << self
    def synchronize_test_catalog
      nlims_service = NlimsSyncUtilsService.new(nil, action_type: nil)
      prev_version = TestCatalogVersion.last&.version || '0'
      new_version_available = nlims_service.check_new_test_catalog_version(prev_version)
      if new_version_available[:is_new_version_available]
        test_catalog = nlims_service.get_test_catalog(new_version_available[:version])
        ActiveRecord::Base.transaction do
          TestCatalogVersion.create!(test_catalog)
          process_test_catalog(test_catalog)
        end
      else
        puts 'No new version'
      end
    end

    def process_test_catalog(test_catalog)
      return false if test_catalog.nil?

      ActiveRecord::Base.transaction do
        create_or_update_specimens(test_catalog[:specimen_types])
        test_catalog[:departments].each do |item|
          create_or_update_department(item)
        end
        create_or_update_drugs(test_catalog[:drugs])
        create_or_update_organisms(test_catalog[:organisms])
        create_or_update_test_types(test_catalog[:test_types])
        create_or_update_test_panels(test_catalog[:test_panels])
      end
      true
    end

    def create_or_update_record(record, data)
      if record.new_record?
        record.name = data[:name]
        record.nlims_code = data[:nlims_code]
        record.preferred_name = data[:preferred_name]
        record.moh_code = data[:moh_code]
        record.loinc_code = data[:loinc_code]
        record.short_name = data[:short_name] if record.respond_to?(:short_name)
        record.description = data[:description]
        record.save!
      else
        attrs = {
          name: data[:name],
          preferred_name: data[:preferred_name],
          moh_code: data[:moh_code],
          loinc_code: data[:loinc_code],
          description: data[:description]
        }
        attrs[:short_name] = data[:short_name] if record.respond_to?(:short_name)
        attrs[:nlims_code] = data[:nlims_code] if record.respond_to?(:nlims_code) && data[:nlims_code].present?
        record.update!(attrs)
      end
      record
    end

    def create_or_update_drugs(drugs)
      drugs.map do |item|
        record = Drug.find_by(nlims_code: item[:nlims_code]) if item[:nlims_code].present?
        record ||= Drug.find_by(scientific_name: item[:scientific_name]) if item[:scientific_name].present?
        record ||= Drug.find_by(name: item[:name])
        record ||= Drug.find_by(name: item[:iblis_mapping_name]) if item[:iblis_mapping_name].present?
        record ||= Drug.new
        create_or_update_record(record, item)
      end
    end

    def create_or_update_organisms(organisms)
      organisms.map do |item|
        record = Organism.find_by(nlims_code: item[:nlims_code]) if item[:nlims_code].present?
        record ||= Organism.find_by(scientific_name: item[:scientific_name]) if item[:scientific_name].present?
        record ||= Organism.find_by(name: item[:name])
        record ||= Organism.find_by(name: item[:iblis_mapping_name]) if item[:iblis_mapping_name].present?
        record ||= Organism.new
        record = create_or_update_record(record, item)
        record.drugs = create_or_update_drugs(item[:drugs])
        record
      end
    end

    def create_or_update_specimens(specimens)
      specimens.map do |item|
        record = SpecimenType.find_by(nlims_code: item[:nlims_code]) if item[:nlims_code].present?
        record ||= SpecimenType.find_by(scientific_name: item[:scientific_name]) if item[:scientific_name].present?
        record ||= SpecimenType.find_by(name: item[:name])
        record ||= SpecimenType.find_by(name: item[:iblis_mapping_name]) if item[:iblis_mapping_name].present?
        record ||= SpecimenType.new
        create_or_update_record(record, item)
      end
    end

    def create_or_update_department(item)
      record = TestCategory.find_by(nlims_code: item[:nlims_code]) if item[:nlims_code].present?
      record ||= TestCategory.find_by(scientific_name: item[:scientific_name]) if item[:scientific_name].present?
      record ||= TestCategory.find_by(name: item[:name])
      record ||= TestCategory.find_by(name: item[:iblis_mapping_name]) if item[:iblis_mapping_name].present?
      record ||= TestCategory.new
      create_or_update_record(record, item)
    end

    def create_or_update_test_indicator_ranges(test_indicator_ranges, measures_id)
      unless test_indicator_ranges.empty?
        MeasureRange.where(measures_id:).each do |test_indicator_range|
          test_indicator_range.destroy!
        end
      end
      test_indicator_ranges.map do |test_indicator_range|
        MeasureRange.find_or_create_by!(
          measures_id:,
          age_min: test_indicator_range[:age_min],
          age_max: test_indicator_range[:age_max],
          range_lower: test_indicator_range[:range_lower],
          range_upper: test_indicator_range[:range_upper],
          value: test_indicator_range[:value],
          interpretation: test_indicator_range[:interpretation],
          sex: test_indicator_range[:sex] || 'Both'
        )
      end
    end

    def create_or_update_test_indicators(test_indicators)
      test_indicators.map do |item|
        record = Measure.find_by(nlims_code: item[:nlims_code], unit: item[:unit]) if item[:nlims_code].present?
        record ||= Measure.find_by(scientific_name: item[:scientific_name], unit: item[:unit]) if item[:scientific_name].present?
        record ||= Measure.find_by(name: item[:iblis_mapping_name], unit: item[:unit]) if item[:iblis_mapping_name].present?
        record ||= Measure.find_by(preferred_name: item[:preferred_name], unit: item[:unit]) if item[:preferred_name].present?
        record ||= Measure.find_by(name: item[:name], unit: item[:unit])
        record ||= Measure.find_by(id: item[:id], nlims_code: item[:nlims_code]) if item[:nlims_code].present?
        record ||= Measure.new
        if record.new_record?
          record.name = item[:name]
          record.measure_type_id = MeasureType.find_by(name: item[:measure_type][:name])&.id
          record.unit = item[:unit] if item[:unit].present?
          record.save!
        end
        indicator = create_or_update_record(record, item)
        create_or_update_test_indicator_ranges(item[:measure_ranges_attributes], indicator.id)
        indicator
      end
    end

    def create_or_update_test_types(test_types)
      test_types.each do |item|
        puts "Processing test type #{item[:name]}"
        record = TestType.find_by(nlims_code: item[:nlims_code]) if item[:nlims_code].present?
        record ||= TestType.find_by(scientific_name: item[:scientific_name]) if item[:scientific_name].present?
        record ||= TestType.find_by(name: item[:name])
        record ||= TestType.find_by(name: item[:preferred_name]) if item[:preferred_name].present?
        record ||= TestType.find_by(name: item[:iblis_mapping_name]) if item[:iblis_mapping_name].present?
        record ||= TestType.new
        if record.new_record?
          record.name = item[:name]
          record.test_category = create_or_update_department(item[:test_category])
          record.can_be_done_on_sex = item[:can_be_done_on_sex] if item[:can_be_done_on_sex].present?
          record.save!
        end
        test_type = create_or_update_record(record, item)
        test_type.measures = create_or_update_test_indicators(item[:measures])
        test_type.specimen_types = create_or_update_specimens(item[:specimen_types])
        test_type.organisms = create_or_update_organisms(item[:organisms])
        test_type.assay_format = item[:assay_format]
        test_type.hr_cadre_required = item[:hr_cadre_required]
        test_type.targetTAT = item[:targetTAT]
        test_type.lab_test_sites = create_or_update_lab_test_sites(item[:lab_test_sites])
        test_type.test_category = create_or_update_department(item[:test_category])
        test_type.save!
      end
    end

    def create_or_update_lab_test_sites(lab_test_sites)
      lab_test_sites.map do |item|
        record = LabTestSite.find_by(name: item[:name])
        record ||= LabTestSite.new
        if record.new_record?
          record.name = item[:name]
          record.description = item[:description]
          record.save!
        else
          record.update!(name: item[:name], description: item[:description])
        end
        record
      end
    end

    def create_or_update_test_panels(test_panels)
      test_panels.each do |item|
        puts "Processing test panel #{item[:name]}"
        record = PanelType.find_by(nlims_code: item[:nlims_code]) if item[:nlims_code].present?
        record ||= PanelType.find_by(scientific_name: item[:scientific_name]) if item[:scientific_name].present?
        record ||= PanelType.find_by(name: item[:name])
        record ||= PanelType.new
        if record.new_record?
          record.name = item[:name]
          record.description = item[:description]
          record.save!
        else
          record = create_or_update_record(record, item)
        end
        record.test_types = TestType.where(name: item[:test_types].map { |tt| tt[:name] })
      end
    end
  end
end
