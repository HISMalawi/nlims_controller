class CatalogService
  def initialize(catalog)
    @catalog = catalog
  end

  # Update test type in JSON catalog
  def update_test_type(id, params)
    test_type_data = find_test_type_in_catalog(id)
    raise ActiveRecord::RecordNotFound, 'Test type not found' unless test_type_data.present?

    # Extract params from nested structure
    catalog_params = params[:test_catalog] || params
    test_type_params = catalog_params[:test_type] || {}

    # Update basic attributes
    update_basic_attributes(test_type_data, test_type_params)

    # Update associations
    update_specimen_types(test_type_data, catalog_params[:specimen_types])
    update_measures(test_type_data, catalog_params[:measures])
    update_organisms(test_type_data, catalog_params[:organisms])
    update_lab_test_sites(test_type_data, catalog_params[:lab_test_sites])
    update_equipment(test_type_data, catalog_params[:equipment])

    # Update timestamp
    test_type_data['updated_at'] = Time.now

    @catalog.save!
    test_type_data
  end

  # Create new test type in JSON catalog
  def create_test_type(params)
    # Extract params from nested structure
    catalog_params = params[:test_catalog] || params
    test_type_params = catalog_params[:test_type] || {}

    test_type_data = initialize_test_type(test_type_params)

    # Add associations
    update_specimen_types(test_type_data, catalog_params[:specimen_types])
    update_measures(test_type_data, catalog_params[:measures])
    update_organisms(test_type_data, catalog_params[:organisms])
    update_lab_test_sites(test_type_data, catalog_params[:lab_test_sites])
    update_equipment(test_type_data, catalog_params[:equipment])

    @catalog.catalog['test_types'] ||= []
    @catalog.catalog['test_types'] << test_type_data
    @catalog.save!

    test_type_data
  end

  # Delete test type from JSON catalog
  def delete_test_type(id)
    @catalog.catalog['test_types']&.reject! do |tt|
      tt['id'] == id.to_i
    end
    @catalog.save!
  end

  # Specimen Type CRUD methods
  def create_specimen_type(params)
    specimen_params = params[:specimen_type] || params

    specimen_type_data = initialize_specimen_type(specimen_params)

    @catalog.catalog['specimen_types'] ||= []
    @catalog.catalog['specimen_types'] << specimen_type_data
    @catalog.save!

    specimen_type_data
  end

  def update_specimen_type(id, params)
    specimen_type_data = find_specimen_type_in_catalog(id)
    raise ActiveRecord::RecordNotFound, 'Specimen type not found' unless specimen_type_data.present?

    specimen_params = params[:specimen_type] || params

    # Update attributes
    specimen_params.each do |key, value|
      key_str = key.to_s
      next if key_str == 'id'

      specimen_type_data[key_str] = value
    end

    specimen_type_data['updated_at'] = Time.now

    @catalog.save!
    specimen_type_data
  end

  def delete_specimen_type(id)
    @catalog.catalog['specimen_types']&.reject! do |st|
      st['id'] == id.to_i
    end
    @catalog.save!
  end

  # Test Panel CRUD methods
  def create_test_panel(params)
    test_panel_params = params[:test_panel] || params

    test_panel_data = initialize_test_panel(test_panel_params)

    # Add test types association
    update_test_panel_test_types(test_panel_data, params[:test_types])

    @catalog.catalog['test_panels'] ||= []
    @catalog.catalog['test_panels'] << test_panel_data
    @catalog.save!

    test_panel_data
  end

  def update_test_panel(id, params)
    test_panel_data = find_test_panel_in_catalog(id)
    raise ActiveRecord::RecordNotFound, 'Test panel not found' unless test_panel_data.present?

    test_panel_params = params[:test_panel] || params

    # Update attributes
    test_panel_params.each do |key, value|
      key_str = key.to_s
      next if key_str == 'id'

      test_panel_data[key_str] = value
    end
    # Update test types association
    update_test_panel_test_types(test_panel_data, params[:test_types])

    test_panel_data['updated_at'] = Time.now

    @catalog.save!
    test_panel_data
  end

  def delete_test_panel(id)
    @catalog.catalog['test_panels']&.reject! do |tp|
      tp['id'] == id.to_i
    end
    @catalog.save!
  end

  def create_drug(params)
    drug_params = params[:drug] || params

    drug_data = initialize_drug(drug_params)

    @catalog.catalog['drugs'] ||= []
    @catalog.catalog['drugs'] << drug_data
    @catalog.save!

    drug_data
  end

  def update_drug(id, params)
    drug_data = find_drug_in_catalog(id)
    raise ActiveRecord::RecordNotFound, 'Drug not found' unless drug_data.present?

    drug_params = params[:drug] || params

    # Update attributes
    drug_params.each do |key, value|
      key_str = key.to_s
      next if key_str == 'id'

      drug_data[key_str] = value
    end

    drug_data['updated_at'] = Time.now

    @catalog.save!
    drug_data
  end

  def delete_drug(id)
    @catalog.catalog['drugs']&.reject! do |d|
      d['id'] == id.to_i
    end
    @catalog.save!
  end

  def create_department(params)
    department_params = params[:department] || params

    department_data = initialize_department(department_params)

    @catalog.catalog['departments'] ||= []
    @catalog.catalog['departments'] << department_data
    @catalog.save!

    department_data
  end

  def update_department(id, params)
    department_data = find_department_in_catalog(id)
    raise ActiveRecord::RecordNotFound, 'Department not found' unless department_data.present?

    department_params = params[:department] || params

    # Update attributes
    department_params.each do |key, value|
      key_str = key.to_s
      next if key_str == 'id'

      department_data[key_str] = value
    end

    department_data['updated_at'] = Time.now
    @catalog.save!
    department_data
  end

  def delete_department(id)
    @catalog.catalog['departments']&.reject! do |d|
      d['id'].to_s == id.to_s
    end
    @catalog.save!
  end

  def create_organism(params)
    organism_params = params[:organism]
    organism_data = initialize_organism(organism_params)

    # Serialize drugs if provided
    update_organism_drugs(organism_data, params[:drugs]) if params[:drugs]

    @catalog.catalog['organisms'] ||= []
    @catalog.catalog['organisms'] << organism_data
    @catalog.save!

    organism_data
  end

  def update_organism(id, params)
    organism_data = find_organism_in_catalog(id)
    raise ActiveRecord::RecordNotFound, 'Organism not found' unless organism_data.present?

    organism_params = params[:organism] || params

    # Update basic attributes
    organism_params.each do |key, value|
      key_str = key.to_s
      next if key_str == 'id'

      organism_data[key_str] = value
    end

    # Update drugs as full objects if provided
    update_organism_drugs(organism_data, params[:drugs]) if params[:drugs]

    organism_data['updated_at'] = Time.now
    @catalog.save!
    organism_data
  end

  def delete_organism(id)
    @catalog.catalog['organisms']&.reject! do |o|
      o['id'].to_s == id.to_s
    end
    @catalog.save!
  end

  private

  def find_test_type_in_catalog(id)
    @catalog.catalog['test_types']&.find { |tt| tt['id'].to_s == id.to_s }
  end

  def initialize_test_type(params)
    next_id = (@catalog.catalog['test_types']&.map { |t| t['id'] }&.max || 0) + 1
    {
      'id' => next_id,
      'nlims_code' => params[:nlims_code].present? ? params[:nlims_code] : "NLIMS_TT_#{next_id.to_s.rjust(4, '0')}_MWI",
      'name' => params[:name],
      'preferred_name' => params[:preferred_name],
      'scientific_name' => params[:scientific_name],
      'short_name' => params[:short_name],
      'moh_code' => params[:moh_code],
      'loinc_code' => params[:loinc_code],
      'description' => params[:description],
      'targetTAT' => params[:targetTAT] || params[:target_tat],
      'assay_format' => params[:assay_format],
      'hr_cadre_required' => params[:hr_cadre_required],
      'can_be_done_on_sex' => params[:can_be_done_on_sex],
      'iblis_mapping_name' => params[:iblis_mapping_name],
      'prevalence_threshold' => params[:prevalence_threshold],
      'test_category' => find_test_category_in_catalog(params[:test_category_id]),
      'created_at' => params[:created_at].present? ? params[:created_at] : Time.now,
      'updated_at' => params[:updated_at].present? ? params[:updated_at] : Time.now,
      'specimen_types' => [],
      'measures' => [],
      'organisms' => [],
      'lab_test_sites' => [],
      'equipment' => []
    }
  end

  def initialize_organism(params)
    next_id = (@catalog.catalog['organisms']&.map { |o| o['id'] }&.max || 0) + 1
    {
      'id' => next_id,
      'name' => params[:name],
      'short_name' => params[:short_name],
      'preferred_name' => params[:preferred_name],
      'scientific_name' => params[:scientific_name],
      'description' => params[:description],
      'moh_code' => params[:moh_code],
      'nlims_code' => params[:nlims_code],
      'loinc_code' => params[:loinc_code],
      'created_at' => params[:created_at].present? ? params[:created_at] : Time.now,
      'updated_at' => params[:updated_at].present? ? params[:updated_at] : Time.now,
      'drugs' => []
    }
  end

  def update_basic_attributes(test_type_data, params)
    return unless params

    params.each do |key, value|
      key_str = key.to_s
      next if key_str == 'id'

      # Handle both targetTAT and target_tat
      if %w[target_tat targetTAT].include?(key_str)
        test_type_data['targetTAT'] = value
      else
        test_type_data[key_str] = value
      end
    end
  end

  def update_specimen_types(test_type_data, specimen_type_ids)
    return unless specimen_type_ids

    test_type_data['specimen_types'] = specimen_type_ids.map do |id|
      specimen = find_specimen_type_in_catalog(id) ||
                 SpecimenType.find_by(id: id)

      next unless specimen

      serialize_specimen_type(specimen)
    end.compact
  end

  def update_measures(test_type_data, measures_params)
    return unless measures_params

    test_type_data['measures'] = measures_params.map do |measure_params|
      serialize_measure(measure_params)
    end
  end

  def update_organisms(test_type_data, organism_ids)
    return unless organism_ids

    test_type_data['organisms'] = organism_ids.map do |id|
      organism = find_organism_in_catalog(id) ||
                 Organism.find_by(id: id)

      next unless organism

      serialize_organism(organism)
    end.compact
  end

  def update_lab_test_sites(test_type_data, site_ids)
    return unless site_ids

    test_type_data['lab_test_sites'] = site_ids.map do |id|
      site = find_lab_test_site_in_catalog(id) ||
             LabTestSite.find_by(id: id)

      next unless site

      serialize_lab_test_site(site)
    end.compact
  end

  def update_equipment(test_type_data, equipment_ids)
    return unless equipment_ids

    test_type_data['equipment'] = equipment_ids.map do |id|
      equip = find_equipment_in_catalog(id) ||
              Equipment.find_by(id: id)

      next unless equip

      serialize_equipment(equip)
    end.compact
  end

  # Serialization helpers
  def serialize_specimen_type(specimen)
    if specimen.is_a?(Hash)
      specimen
    else
      {
        'id' => specimen.id,
        'name' => specimen.name,
        'nlims_code' => specimen.nlims_code,
        'preferred_name' => specimen.preferred_name,
        'scientific_name' => specimen.scientific_name,
        'description' => specimen.description,
        'iblis_mapping_name' => specimen.iblis_mapping_name
      }
    end
  end

  def serialize_measure(measure_params)
    next_id = SecureRandom.uuid
    measure_data = if measure_params.is_a?(Hash)
                     measure_params.deep_stringify_keys
                   else
                     {
                       'id' => measure_params[:id].present? ? measure_params[:id] : next_id,
                       'name' => measure_params[:name],
                       'loinc_code' => measure_params[:loinc_code],
                       'moh_code' => measure_params[:moh_code],
                       'nlims_code' => measure_params[:nlims_code].present? ? measure_params[:nlims_code] : '',
                       'unit' => measure_params[:unit],
                       'iblis_mapping_name' => measure_params[:iblis_mapping_name],
                       'preferred_name' => measure_params[:preferred_name],
                       'scientific_name' => measure_params[:scientific_name],
                       'measure_type_id' => measure_params[:measure_type_id],
                       'short_name' => measure_params[:short_name],
                       'description' => measure_params[:description],
                       'measure_type' => MeasureType.find_by(id: measure_params[:measure_type_id]).as_json,
                       'created_at' => Time.now,
                       'updated_at' => Time.now
                     }
                   end

    # Handle nested measure ranges
    if measure_params.respond_to?(:[]) && measure_params[:measure_ranges_attributes]
      measure_data['measure_ranges_attributes'] = serialize_measure_ranges(
        measure_params[:measure_ranges_attributes], measure_data['id']
      )
    end

    measure_data
  end

  def serialize_measure_ranges(ranges_params, measure_id)
    ranges_params.map do |range_params|
      if range_params.is_a?(Hash)
        range_params.deep_stringify_keys
      else
        {
          'id' => range_params[:id].present? ? range_params[:id] : SecureRandom.uuid,
          'sex' => range_params[:sex],
          'age_max' => range_params[:age_max],
          'age_min' => range_params[:age_min],
          'measure_id' => measure_id,
          'range_lower' => range_params[:range_lower],
          'range_upper' => range_params[:range_upper],
          'value' => range_params[:value],
          'interpretation' => range_params[:interpretation]
        }
      end
    end
  end

  def serialize_organism(organism)
    if organism.is_a?(Hash)
      organism
    else
      {
        'id' => organism.id,
        'name' => organism.name,
        'nlims_code' => organism.nlims_code,
        'preferred_name' => organism.preferred_name
      }
    end
  end

  def serialize_lab_test_site(site)
    if site.is_a?(Hash)
      site
    else
      {
        'id' => site.id,
        'name' => site.name,
        'description' => site.description
      }
    end
  end

  def serialize_equipment(equipment)
    if equipment.is_a?(Hash)
      equipment
    else
      {
        'id' => equipment.id,
        'name' => equipment.name,
        'description' => equipment.description
      }
    end
  end

  # Finders in catalog
  def find_specimen_type_in_catalog(id)
    @catalog.catalog['specimen_types']&.find { |s| s['id'] == id.to_i }
  end

  def find_organism_in_catalog(id)
    @catalog.catalog['organisms']&.find { |o| o['id'] == id.to_i }
  end

  def find_lab_test_site_in_catalog(id)
    @catalog.catalog['lab_test_sites']&.find { |l| l['id'] == id.to_i }
  end

  def find_equipment_in_catalog(id)
    @catalog.catalog['equipment']&.find { |e| e['id'] == id.to_i }
  end

  def find_test_category_in_catalog(id)
    @catalog.catalog['departments']&.find { |d| d['id'] == id.to_i }
  end

  def initialize_specimen_type(params)
    next_id = (@catalog.catalog['specimen_types']&.map { |st| st['id'] }&.max || 0) + 1
    {
      'id' => next_id,
      'nlims_code' => params[:nlims_code] || "NLIMS_SP_#{next_id.to_s.rjust(4, '0')}_MWI",
      'name' => params[:name],
      'preferred_name' => params[:preferred_name],
      'scientific_name' => params[:scientific_name],
      'moh_code' => params[:moh_code],
      'loinc_code' => params[:loinc_code],
      'description' => params[:description],
      'iblis_mapping_name' => params[:iblis_mapping_name],
      'created_at' => params[:created_at].present? ? params[:created_at] : Time.now,
      'updated_at' => params[:updated_at].present? ? params[:updated_at] : Time.now
    }
  end

  def initialize_drug(params)
    next_id = (@catalog.catalog['drugs']&.map { |d| d['id'] }&.max || 0) + 1
    {
      'id' => next_id,
      'name' => params[:name],
      'preferred_name' => params[:preferred_name],
      'scientific_name' => params[:scientific_name],
      'short_name' => params[:short_name],
      'description' => params[:description],
      'nlims_code' => params[:nlims_code] || "NLIMS_DRG_#{next_id.to_s.rjust(4, '0')}_MWI",
      'loinc_code' => params[:loinc_code],
      'moh_code' => params[:moh_code],
      'created_at' => params[:created_at].present? ? params[:created_at] : Time.now,
      'updated_at' => params[:updated_at].present? ? params[:updated_at] : Time.now
    }
  end

  def initialize_department(params)
    next_id = (@catalog.catalog['departments']&.map { |d| d['id'] }&.max || 0) + 1
    {
      'id' => next_id,
      'name' => params[:name],
      'preferred_name' => params[:preferred_name],
      'scientific_name' => params[:scientific_name],
      'short_name' => params[:short_name],
      'description' => params[:description],
      'nlims_code' => params[:nlims_code] || "NLIMS_TC_#{next_id.to_s.rjust(4, '0')}_MWI",
      'loinc_code' => params[:loinc_code],
      'moh_code' => params[:moh_code],
      'created_at' => params[:created_at].present? ? params[:created_at] : Time.now,
      'updated_at' => params[:updated_at].present? ? params[:updated_at] : Time.now
    }
  end

  def find_department_in_catalog(id)
    @catalog.catalog['departments']&.find { |d| d['id'] == id.to_i }
  end

  def find_test_panel_in_catalog(id)
    @catalog.catalog['test_panels']&.find { |tp| tp['id'] == id.to_i }
  end

  def find_drug_in_catalog(id)
    @catalog.catalog['drugs']&.find { |d| d['id'] == id.to_i }
  end

  def initialize_test_panel(params)
    next_id = (@catalog.catalog['test_panels']&.map { |tp| tp['id'] }&.max || 0) + 1
    {
      'id' => next_id,
      'nlims_code' => params[:nlims_code] || "NLIMS_TP_#{next_id.to_s.rjust(4, '0')}_MWI",
      'name' => params[:name],
      'preferred_name' => params[:preferred_name],
      'scientific_name' => params[:scientific_name],
      'short_name' => params[:short_name],
      'moh_code' => params[:moh_code],
      'loinc_code' => params[:loinc_code],
      'description' => params[:description],
      'created_at' => params[:created_at].present? ? params[:created_at] : Time.now,
      'updated_at' => params[:updated_at].present? ? params[:updated_at] : Time.now,
      'test_types' => []
    }
  end

  def update_test_panel_test_types(test_panel_data, test_type_ids)
    return unless test_type_ids

    test_panel_data['test_types'] = test_type_ids.map do |id|
      test_type = find_test_type_in_catalog(id) ||
                  TestType.find_by(id: id)

      next unless test_type

      serialize_test_type(test_type)
    end.compact
  end

  def update_organism_drugs(organism_data, drug_ids)
    return unless drug_ids.is_a?(Array)

    organism_data['drugs'] = drug_ids.map do |id|
      drug = find_drug_in_catalog(id) || Drug.find_by(id: id).as_json
      next unless drug

      drug
    end
  end

  def serialize_test_type(test_type)
    if test_type.is_a?(Hash)
      test_type
    else
      {
        'id' => test_type.id,
        'name' => test_type.name,
        'nlims_code' => test_type.nlims_code,
        'preferred_name' => test_type.preferred_name,
        'scientific_name' => test_type.scientific_name,
        'short_name' => test_type.short_name,
        'description' => test_type.description
      }
    end
  end
end
