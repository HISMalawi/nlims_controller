# frozen_string_literal: true

# TestType model
class TestType < ApplicationRecord
    include Codeable
    has_many :test_results, dependent: :restrict_with_error
    has_many :tests, dependent: :restrict_with_error
    belongs_to :test_category, class_name: 'TestCategory', foreign_key: 'test_category_id'
    has_many :testtype_specimentypes, class_name: 'TesttypeSpecimentype'
    has_many :specimen_types, through: :testtype_specimentypes
    has_many :testtype_measures, class_name: 'TesttypeMeasure'
    has_many :measures, through: :testtype_measures
     has_many :testtype_organisms, class_name: 'TesttypeOrganism'
    has_many :organisms, through: :testtype_organisms

    NLIMS_CODE_PREFIX = 'TT'

    def self.get_test_type_id(type)
      TestType.find_by(name: type)&.id
    end

    def as_json(options = {})
        if options[:context] == :single_item
            super(options.merge(
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
                  }
                }
              ))
        else
            super()
        end
    end

    # def organisms
    #   testtype_organisms = TesttypeOrganism.where(test_type_id: id).map(&:organism_id)
    #   Organism.where(id: testtype_organisms)
    # end
end
