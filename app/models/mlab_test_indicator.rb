# frozen_string_literal: true

# MlabTestIndicator model - reads from mlab database test_indicators table
class MlabTestIndicator < MlabBase
  self.table_name = 'test_indicators'

  has_many :mlab_test_results, foreign_key: 'test_indicator_id', class_name: 'MlabTestResult'

  scope :not_retired, -> { where('retired IS NULL OR retired = 0') }
end
