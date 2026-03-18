# frozen_string_literal: true

# MlabTestTypeTestIndicator model - reads from mlab database test_type_indicator_mappings table
# This table maps test types to test indicators and includes the unit for each combination
class MlabTestTypeTestIndicator < MlabBase
  self.table_name = 'test_type_indicator_mappings'

  belongs_to :mlab_test_type, foreign_key: 'test_types_id', class_name: 'MlabTestType'
  belongs_to :mlab_test_indicator, foreign_key: 'test_indicators_id', class_name: 'MlabTestIndicator'

  scope :not_voided, lambda {
    where('test_type_indicator_mappings.voided IS NULL OR test_type_indicator_mappings.voided = 0')
  }
end
