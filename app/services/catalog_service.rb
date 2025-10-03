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
    test_type_data['updated_at'] = Time.current.iso8601

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

  private

  def find_test_type_in_catalog(id)
    @catalog.catalog['test_types']&.find { |tt| tt['id'].to_s == id.to_s }
  end

  def initialize_test_type(params)
    next_id = (@catalog.catalog['test_types']&.map { |t| t['id'] }&.max || 0) + 1

    {
      'id' => next_id,
      'nlims_code' => params[:nlims_code] || "NLIMS_TT_#{next_id.to_s.rjust(4, '0')}_MWI",
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
      'test_category_id' => params[:test_category_id],
      'created_at' => params[:created_at] || Time.current.iso8601,
      'updated_at' => params[:updated_at] || Time.current.iso8601,
      'specimen_types' => [],
      'measures' => [],
      'organisms' => [],
      'lab_test_sites' => [],
      'equipment' => []
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
    measure_data = if measure_params.is_a?(Hash)
                     measure_params.deep_stringify_keys
                   else
                     {
                       'id' => measure_params[:id],
                       'name' => measure_params[:name],
                       'nlims_code' => measure_params[:nlims_code],
                       'unit' => measure_params[:unit],
                       'preferred_name' => measure_params[:preferred_name],
                       'measure_type_id' => measure_params[:measure_type_id]
                     }
                   end

    # Handle nested measure ranges
    if measure_params.respond_to?(:[]) && measure_params[:measure_ranges_attributes]
      measure_data['measure_ranges_attributes'] = serialize_measure_ranges(
        measure_params[:measure_ranges_attributes]
      )
    end

    measure_data
  end

  def serialize_measure_ranges(ranges_params)
    ranges_params.map do |range_params|
      range_params.is_a?(Hash) ? range_params.deep_stringify_keys : range_params.to_json
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
end
