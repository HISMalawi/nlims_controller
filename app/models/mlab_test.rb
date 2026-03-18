# frozen_string_literal: true

# MlabTest model - reads from mlab database tests table
class MlabTest < MlabBase
  self.table_name = 'tests'

  belongs_to :mlab_order, foreign_key: 'order_id', class_name: 'MlabOrder'
  belongs_to :mlab_specimen, foreign_key: 'specimen_id', class_name: 'MlabSpecimen', optional: true
  belongs_to :mlab_test_type, foreign_key: 'test_type_id', class_name: 'MlabTestType'
  belongs_to :mlab_status, foreign_key: 'status_id', class_name: 'MlabStatus', optional: true
  has_many :mlab_test_statuses, foreign_key: 'test_id', class_name: 'MlabTestStatus'
  has_many :mlab_test_results, foreign_key: 'test_id', class_name: 'MlabTestResult'

  scope :not_voided, -> { where('tests.voided IS NULL OR tests.voided = 0') }
  scope :recent_first, -> { order(created_date: :desc) }

  # Get current status name directly from status_id
  def current_status
    mlab_status&.name
  end
end
