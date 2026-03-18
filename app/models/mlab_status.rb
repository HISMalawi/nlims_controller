# frozen_string_literal: true

# MlabStatus model - reads from mlab database statuses table
class MlabStatus < MlabBase
  self.table_name = 'statuses'

  has_many :mlab_test_statuses, foreign_key: 'status_id', class_name: 'MlabTestStatus'

  scope :not_retired, -> { where('retired IS NULL OR retired = 0') }
end
