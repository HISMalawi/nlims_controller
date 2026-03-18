# frozen_string_literal: true

# MlabTestStatus model - reads from mlab database test_statuses table
class MlabTestStatus < MlabBase
  self.table_name = 'test_statuses'

  belongs_to :mlab_test, foreign_key: 'test_id', class_name: 'MlabTest'
  belongs_to :mlab_status, foreign_key: 'status_id', class_name: 'MlabStatus'

  scope :not_voided, -> { where('test_statuses.voided IS NULL OR test_statuses.voided = 0') }
end
