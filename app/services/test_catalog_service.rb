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

  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/AbcSize
  def self.create_test_type(params)
    ActiveRecord::Base.transaction do
      @test_type = TestType.create!(params[:test_type])
      params[:specimen_types].each do |specimen_type_id|
        TesttypeSpecimentype.create!(specimen_type_id:, test_type_id: @test_type.id)
      end
      measures = create_test_indicator(params)
      measures.each do |measure|
        TesttypeMeasure.create!(measure_id: measure.id, test_type_id: @test_type.id)
      end
      params[:organisms].each do |organism_id|
        TesttypeOrganism.create!(organism_id:, test_type_id: @test_type.id)
      end
    end
    @test_type
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength

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
end
