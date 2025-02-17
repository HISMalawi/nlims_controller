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
          name: 'measure',
          short_name: 'measure',
          unit: 'measure',
          measure_type_id: 1,
          description: 'measure',
          loinc_code: 'measure',
          moh_code: 'measure',
          nlims_code: 'measure',
          preferred_name: 'measure',
          scientific_name: 'measure',
          measure_ranges: [
            age_min: 1,
            age_max: 1,
            range_lower: 2,
            range_upper: 2,
            sex: 'Male' || 'Female' || 'Both',
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
      Measure.create!(params['measures'])
    end
end
