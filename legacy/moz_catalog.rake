# frozen_string_literal: true

# Builds the Mozambique test catalog from the mLab database and loads it into NLIMS.
#
#   rake moz_catalog:export                 # mlab -> db/moz_test_catalog.json
#   rake moz_catalog:import                 # json -> NLIMS via ProcessTestCatalogService
#   rake moz_catalog:purge_foreign_catalog  # drops every catalog record not in the MOZ set
#
# Connection to mLab is taken from MLAB_DB_* env vars, defaulting to the local instance.
namespace :moz_catalog do
  CATALOG_PATH = Rails.root.join('db', 'moz_test_catalog.json')
  CODE_SUFFIX = 'MOZ'

  # mLab TestCatalog::TestTypes::TestIndicatorType -> NLIMS measure_types.name
  MEASURE_TYPES = {
    0 => 'AutoComplete',
    1 => 'Free Text',
    2 => 'Numeric',
    3 => 'AlphaNumeric',
    4 => 'Rich Text'
  }.freeze

  def mlab
    @mlab ||= Mysql2::Client.new(
      host: ENV.fetch('MLAB_DB_HOST', '127.0.0.1'),
      port: ENV.fetch('MLAB_DB_PORT', 3306).to_i,
      username: ENV.fetch('MLAB_DB_USER', 'root'),
      password: ENV.fetch('MLAB_DB_PASSWORD', '2448'),
      database: ENV.fetch('MLAB_DB_NAME', 'mlab'),
      encoding: 'utf8mb4'
    )
  end

  def query(sql)
    mlab.query(sql, symbolize_keys: true).to_a
  end

  def code(prefix, id)
    "NLIMS_#{prefix}_#{id.to_s.rjust(4, '0')}_#{CODE_SUFFIX}"
  end

  # Fields every catalog record carries, as read by ProcessTestCatalogService#create_or_update_record.
  def base_record(row, prefix)
    {
      id: row[:id],
      name: row[:name],
      preferred_name: row[:name],
      short_name: row[:short_name],
      description: row[:description].presence || '',
      nlims_code: code(prefix, row[:id]),
      moh_code: nil,
      loinc_code: nil,
      scientific_name: nil,
      iblis_mapping_name: nil
    }
  end

  desc 'Export the Mozambique test catalog from the mLab database'
  task export: :environment do
    # mLab retires departments that its own active test types still point at (Banco de Sangue,
    # Biologia Molecular, ...), so keep any department an active test type depends on.
    departments = query(<<~SQL).index_by { |row| row[:id] }
      SELECT id, name, code FROM departments
      WHERE retired IS NULL OR retired = 0
         OR id IN (SELECT department_id FROM test_types WHERE retired IS NULL OR retired = 0)
    SQL
    departments = departments.transform_values do |row|
      base_record(row.merge(short_name: row[:name], description: ''), 'TC').merge(moh_code: row[:code])
    end

    specimen_types = query(<<~SQL).index_by { |row| row[:id] }
      SELECT id, name, description FROM specimen WHERE retired IS NULL OR retired = 0
    SQL
    specimen_types = specimen_types.transform_values do |row|
      base_record(row.merge(short_name: nil), 'SP').merge(iblis_mapping_name: row[:name])
    end

    drugs = query(<<~SQL).index_by { |row| row[:id] }
      SELECT id, name, short_name FROM drugs WHERE retired IS NULL OR retired = 0
    SQL
    drugs = drugs.transform_values { |row| base_record(row.merge(description: ''), 'DRG') }

    organisms = query(<<~SQL).index_by { |row| row[:id] }
      SELECT id, name, description FROM organisms WHERE retired IS NULL OR retired = 0
    SQL
    drugs_by_organism = query(<<~SQL).group_by { |row| row[:organism_id] }
      SELECT organism_id, drug_id FROM drug_organism_mappings WHERE retired IS NULL OR retired = 0
    SQL
    organisms = organisms.transform_values do |row|
      base_record(row.merge(short_name: nil), 'ORG').merge(
        drugs: (drugs_by_organism[row[:id]] || []).filter_map { |link| drugs[link[:drug_id]] }
      )
    end

    ranges_by_indicator = query(<<~SQL).group_by { |row| row[:test_indicator_id] }
      SELECT test_indicator_id, min_age, max_age, sex, lower_range, upper_range, interpretation, value
      FROM test_indicator_ranges WHERE retired IS NULL OR retired = 0
    SQL

    indicators = query(<<~SQL).index_by { |row| row[:id] }
      SELECT id, name, unit, description, test_indicator_type
      FROM test_indicators WHERE retired IS NULL OR retired = 0
    SQL
    indicators = indicators.transform_values do |row|
      base_record(row.merge(short_name: nil), 'TI').merge(
        unit: row[:unit].presence,
        measure_type: { name: MEASURE_TYPES.fetch(row[:test_indicator_type], 'Free Text') },
        measure_ranges_attributes: (ranges_by_indicator[row[:id]] || []).map do |range|
          {
            age_min: range[:min_age],
            age_max: range[:max_age],
            sex: range[:sex].presence || 'Both',
            range_lower: range[:lower_range],
            range_upper: range[:upper_range],
            interpretation: range[:interpretation],
            value: range[:value]
          }
        end
      )
    end

    indicators_by_test_type = query(<<~SQL).group_by { |row| row[:test_types_id] }
      SELECT test_types_id, test_indicators_id FROM test_type_indicator_mappings
      WHERE voided IS NULL OR voided = 0
    SQL
    specimens_by_test_type = query(<<~SQL).group_by { |row| row[:test_type_id] }
      SELECT test_type_id, specimen_id FROM specimen_test_type_mappings WHERE retired IS NULL OR retired = 0
    SQL
    organisms_by_test_type = query(<<~SQL).group_by { |row| row[:test_type_id] }
      SELECT test_type_id, organism_id FROM test_type_organism_mappings WHERE retired IS NULL OR retired = 0
    SQL
    tats = query(<<~SQL).index_by { |row| row[:test_type_id] }
      SELECT test_type_id, value, unit FROM expected_tats WHERE voided IS NULL OR voided = 0
    SQL

    test_type_rows = query(<<~SQL)
      SELECT id, name, short_name, department_id, sex FROM test_types WHERE retired IS NULL OR retired = 0
    SQL
    test_types = test_type_rows.map do |row|
      tat = tats[row[:id]]
      base_record(row.merge(description: ''), 'TT').merge(
        targetTAT: tat && "#{tat[:value]} #{tat[:unit]}".strip,
        assay_format: nil,
        hr_cadre_required: nil,
        prevalence_threshold: '',
        can_be_done_on_sex: row[:sex].presence || 'Both',
        test_category: departments[row[:department_id]],
        measures: (indicators_by_test_type[row[:id]] || []).filter_map { |link| indicators[link[:test_indicators_id]] },
        specimen_types: (specimens_by_test_type[row[:id]] || []).filter_map { |link| specimen_types[link[:specimen_id]] },
        organisms: (organisms_by_test_type[row[:id]] || []).filter_map { |link| organisms[link[:organism_id]] },
        lab_test_sites: []
      )
    end
    test_types_by_id = test_types.index_by { |test_type| test_type[:id] }

    test_types_by_panel = query(<<~SQL).group_by { |row| row[:test_panel_id] }
      SELECT test_panel_id, test_type_id FROM test_type_panel_mappings WHERE voided IS NULL OR voided = 0
    SQL
    test_panel_rows = query(<<~SQL)
      SELECT id, name, short_name, description FROM test_panels WHERE retired IS NULL OR retired = 0
    SQL
    test_panels = test_panel_rows.map do |row|
      base_record(row, 'TP').merge(
        test_types: (test_types_by_panel[row[:id]] || []).filter_map { |link| test_types_by_id[link[:test_type_id]] }
      )
    end

    catalog = {
      drugs: drugs.values,
      organisms: organisms.values,
      departments: departments.values,
      specimen_types: specimen_types.values,
      test_types:,
      test_panels:
    }

    File.write(CATALOG_PATH, JSON.pretty_generate(catalog))
    puts "Wrote #{CATALOG_PATH}"
    catalog.each { |key, value| puts format('  %-16s %d', key, value.size) }
    puts "  #{'measures'.ljust(16)} #{test_types.sum { |t| t[:measures].size }} (#{indicators.size} distinct)"
  end

  # ProcessTestCatalogService#create_or_update_test_panels is the one path that does not carry
  # nlims_code over when it creates a record, so Codeable stamps a generated code instead. Put the
  # catalog's own code back, otherwise the panels look foreign to purge_foreign_catalog.
  def stamp_panel_codes(test_panels)
    test_panels.each do |item|
      PanelType.where(name: item[:name]).update_all(nlims_code: item[:nlims_code])
    end
  end

  desc 'Load the exported Mozambique catalog into NLIMS'
  task import: :environment do
    catalog = JSON.parse(File.read(CATALOG_PATH), symbolize_names: true)

    ActiveRecord::Base.transaction do
      # Re-importing an unchanged catalog should refresh the records without piling up version rows.
      version = TestCatalogVersion.last
      unless version&.catalog == catalog.to_json
        version = TestCatalogVersion.create!(catalog: catalog.to_json, status: 'approved-release')
      end
      ProcessTestCatalogService.process_test_catalog(catalog)
      stamp_panel_codes(catalog[:test_panels])
      puts "Imported as test catalog #{version.version}"
    end

    puts "  test_types      #{TestType.where('nlims_code LIKE ?', "%_#{CODE_SUFFIX}").count}"
    puts "  specimen_types  #{SpecimenType.where('nlims_code LIKE ?', "%_#{CODE_SUFFIX}").count}"
    puts "  measures        #{Measure.where('nlims_code LIKE ?', "%_#{CODE_SUFFIX}").count}"
  end

  desc 'Delete every catalog record that is not part of the Mozambique catalog'
  task purge_foreign_catalog: :environment do
    if Speciman.exists?
      abort 'Refusing to purge: the specimen table is not empty. Restore from a backup path instead.'
    end

    # Qualified with the table name: these scopes get chained onto joins where `nlims_code` is ambiguous.
    mine = ->(scope) { scope.where("#{scope.table_name}.nlims_code LIKE ?", "%_#{CODE_SUFFIX}") }
    foreign = lambda do |scope|
      scope.where("#{scope.table_name}.nlims_code IS NULL OR #{scope.table_name}.nlims_code NOT LIKE ?",
                  "%_#{CODE_SUFFIX}")
    end

    ActiveRecord::Base.transaction do
      test_type_ids = foreign.call(TestType).ids
      measure_ids = foreign.call(Measure).ids
      specimen_type_ids = foreign.call(SpecimenType).ids
      organism_ids = foreign.call(Organism).ids

      Panel.where(test_type_id: test_type_ids).delete_all
      TesttypeMeasure.where(test_type_id: test_type_ids).or(TesttypeMeasure.where(measure_id: measure_ids)).delete_all
      TesttypeSpecimentype.where(test_type_id: test_type_ids)
                          .or(TesttypeSpecimentype.where(specimen_type_id: specimen_type_ids)).delete_all
      TesttypeOrganism.where(test_type_id: test_type_ids).or(TesttypeOrganism.where(organism_id: organism_ids)).delete_all
      TestTypeLabTestSite.where(test_type_id: test_type_ids).delete_all
      MeasureRange.where(measures_id: measure_ids).delete_all
      OrganismDrug.where(organism_id: organism_ids).delete_all

      counts = {
        test_types: TestType.where(id: test_type_ids).delete_all,
        measures: Measure.where(id: measure_ids).delete_all,
        specimen_types: SpecimenType.where(id: specimen_type_ids).delete_all,
        organisms: Organism.where(id: organism_ids).delete_all,
        drugs: foreign.call(Drug).where.missing(:organism_drugs).delete_all,
        panel_types: foreign.call(PanelType).delete_all,
        test_categories: foreign.call(TestCategory).where.missing(:test_types).delete_all
      }
      counts.each { |table, deleted| puts format('  deleted %-16s %d', table, deleted) }

      FailedTestType.where(reason: 'Test Type not avail in NLIMS').delete_all
    end

    puts "Remaining: #{mine.call(TestType).count} test types, #{mine.call(SpecimenType).count} specimen types"
  end
end
