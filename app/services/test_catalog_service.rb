# frozen_string_literal: true

# TestCatalogService for retrieving test catalog and creating test types
module TestCatalogService
  def self.get_test_catalog(_params)
    {
      test_type: {
        name: 'test_type',
        short_name: 'test_type',
        description: 'test_type',
        loinc_code: 'test_type',
        moh_code: 'test_type',
        nlims_code: 'test_type',
        targetTAT: 'test_type hrs',
        preferred_name: 'test_type',
        scientific_name: 'test_type',
        can_be_done_on_sex: 'Female',
        test_category_id: 1
      },
      specimen_types: [1, 2],
      lab_test_sites: [1, 2],
      measures: [
        {
          name: 'measure122333',
          short_name: 'measure122333',
          unit: 'measure122333',
          measure_type_id: 5,
          description: 'measure122333',
          loinc_code: 'measure122333',
          moh_code: 'measure122333',
          nlims_code: 'measure122333',
          preferred_name: 'measure122333',
          scientific_name: 'measure122333',
          measure_ranges_attributes: [
            {
              age_min: 1,
              age_max: 1,
              range_lower: 2,
              range_upper: 2,
              sex: 'Male',
              value: 'measure',
              interpretation: 'measure'
            },
            {
              age_min: 1,
              age_max: 1,
              range_lower: 2,
              range_upper: 2,
              sex: 'Male',
              value: 'measure',
              interpretation: 'measure'
            }
          ]
        },
        {
          name: 'measure122344',
          short_name: 'measure122344',
          unit: 'measure122344',
          measure_type_id: 5,
          description: 'measure122344',
          loinc_code: 'measure122344',
          moh_code: 'measure122344',
          nlims_code: 'measure122344',
          preferred_name: 'measure122344',
          scientific_name: 'measure122344',
          measure_ranges_attributes: [
            {
              age_min: 1,
              age_max: 1,
              range_lower: 2,
              range_upper: 2,
              sex: 'Male',
              value: 'measure',
              interpretation: 'measure'
            },
            {
              age_min: 1,
              age_max: 1,
              range_lower: 2,
              range_upper: 2,
              sex: 'Male',
              value: 'measure',
              interpretation: 'measure'
            }
          ]
        }
      ],
      organisms: [1, 3]
    }
  end

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
    MeasureRange.where.not(
      id: measure_ranges_ids,
      measures_id: measure.id
    ).destroy_all
  end
end
