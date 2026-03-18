# frozen_string_literal: true

# MlabOrderStatus model - reads from mlab database order_statuses table
class MlabOrderStatus < MlabBase
  self.table_name = 'order_statuses'

  belongs_to :mlab_order, foreign_key: 'order_id', class_name: 'MlabOrder'
  belongs_to :mlab_status, foreign_key: 'status_id', class_name: 'MlabStatus'

  scope :not_voided, -> { where('order_statuses.voided IS NULL OR order_statuses.voided = 0') }
end
