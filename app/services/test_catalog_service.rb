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
        can_be_done_on_sex: 'Female' || 'Male' || 'Both',
        test_category_id: 1
      },
      specimen_types: [
        { id: 1, name: 'specimen_Type' },
        { id: 2, name: 'specimen_type' }
      ],
      measures: [
        {
          name: 'measure1',
          short_name: 'measure1',
          unit: 'measure1',
          measure_type_id: 5,
          description: 'measure1',
          loinc_code: 'measure1',
          moh_code: 'measure1',
          nlims_code: 'measure1',
          preferred_name: 'measure1',
          scientific_name: 'measure1',
          measure_ranges_attributes: [
            age_min: 1,
            age_max: 1,
            range_lower: 2,
            range_upper: 2,
            sex: 'Male',
            value: 'measure',
            interpretation: 'measure'
          ]
        }
      ],
      organisms: [
        { id: 1, name: 'organism' }, { id: 2, name: 'organism' }
      ]
    }
  end

    def self.create_test_type(params)
      TestType.create!(params['test_type'])
    end

    def self.create_test_indicator(params)
      Measure.create!(params[:measures])
      # params[:measures]
      # params[:measures][:measure_ranges].each do |_measure_range|
      #   params[:measure_ranges][:measures_id] = measure.id
      #   MeasureRange.find_or_create!(params[:measure_ranges])
      # end
    end

    def self.create_organism(params)
      Organism.create!(params[:organisms])
    end
end
