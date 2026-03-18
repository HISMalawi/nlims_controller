# frozen_string_literal: true

# MlabTestResult model - reads from mlab database test_results table
class MlabTestResult < MlabBase
  self.table_name = 'test_results'

  belongs_to :mlab_test, foreign_key: 'test_id', class_name: 'MlabTest'
  belongs_to :mlab_test_indicator, foreign_key: 'test_indicator_id', class_name: 'MlabTestIndicator'

  scope :not_voided, -> { where('test_results.voided IS NULL OR test_results.voided = 0') }

  # Get the unit for this test result from the test_type_test_indicators join table
  # The unit is specific to the combination of test_type + test_indicator
  def unit
    return '' unless mlab_test && mlab_test_indicator

    join_record = MlabTestTypeTestIndicator.not_voided.find_by(
      test_types_id: mlab_test.test_type_id,
      test_indicators_id: test_indicator_id
    )

    join_record&.unit || ''
  end
end
