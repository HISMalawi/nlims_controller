# frozen_string_literal: true

# MlabTestType model - reads from mlab database test_types table
class MlabTestType < MlabBase
  self.table_name = 'test_types'

  has_many :mlab_tests, foreign_key: 'test_type_id', class_name: 'MlabTest'

  scope :not_retired, -> { where('retired IS NULL OR retired = 0') }
end
