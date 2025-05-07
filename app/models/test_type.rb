# frozen_string_literal: true

# TestType model
class TestType < ApplicationRecord
    include Codeable
    has_many :tests, dependent: :restrict_with_error
    belongs_to :test_category, class_name: 'TestCategory', foreign_key: 'test_category_id'
    has_many :testtype_specimentypes, class_name: 'TesttypeSpecimentype'
    has_many :specimen_types, through: :testtype_specimentypes
    has_many :testtype_measures, class_name: 'TesttypeMeasure'
    has_many :measures, through: :testtype_measures
    has_many :testtype_organisms, class_name: 'TesttypeOrganism'
    has_many :organisms, through: :testtype_organisms
    has_many :test_type_lab_test_sites, class_name: 'TestTypeLabTestSite'
    has_many :lab_test_sites, through: :test_type_lab_test_sites, dependent: :destroy
    has_many :panels, dependent: :restrict_with_error
    has_many :panel_types, through: :panels
    has_and_belongs_to_many :equipment, join_table: :equipment_test_types

    NLIMS_CODE_PREFIX = 'TT'

    def self.get_test_type_id(type)
      TestType.find_by(name: type)&.id
    end

    def as_json(options = {})
        if options[:context] == :single_item
          json_data = super(options.merge(
                except: %i[test_category_id],
                include: {
                  test_category: {},
                  specimen_types: {},
                  measures: {
                    include: {
                        measure_type: {},
                        measure_ranges: {}
                        }
                  },
                  organisms: {
                    include: {
                        drugs: {}
                    }
                  },
                  lab_test_sites: {},
                  equipment: {}
                }
              ))
          json_data['measures'] = json_data['measures'].map do |measure|
            measure['measure_ranges_attributes'] = measure.delete('measure_ranges') if measure['measure_ranges']
            measure
          end
          json_data
        else
            super()
        end
    end
end
