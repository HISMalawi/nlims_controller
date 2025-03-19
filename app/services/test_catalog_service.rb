# frozen_string_literal: true

# TestCatalogService for retrieving test catalog and creating test types
module TestCatalogService
  def self.create_test_type(params)
    ActiveRecord::Base.transaction do
      @test_type = TestType.create!(params[:test_type])
      @test_type.specimen_types = SpecimenType.where(id: params[:specimen_types])
      @test_type.measures = update_test_measures(params)
      @test_type.organisms = Organism.where(id: params[:organisms])
      @test_type.lab_test_sites = LabTestSite.where(id: params[:lab_test_sites])
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
    end
    @test_type
  end

  # rubo
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
      test_types: TestType.all.as_json({ context: :single_item })
    }
  end

  def self.approve_test_catalog
    TestCatalogVersion.create!(catalog: get_test_catalog, creator: User.current&.id)
  end

  def self.retrieve_test_catalog(version)
    return TestCatalogVersion.find_by(version:) if version.present?

    TestCatalogVersion.last
  end

  def self.test_catalog_versions
    TestCatalogVersion.all.select(:id, :version, :created_at).order(created_at: :desc)
  end

  def self.new_version_available?(previous_version)
    latest_version = TestCatalogVersion.order(version: :desc).pick(:version)
    return { is_new_version_available: false, version: latest_version } unless latest_version.present?

    {
      is_new_version_available: latest_version > previous_version,
      version: latest_version
    }
  end
end
