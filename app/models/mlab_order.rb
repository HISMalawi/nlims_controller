# frozen_string_literal: true

# MlabOrder model - reads from mlab database orders table
class MlabOrder < MlabBase
  self.table_name = 'orders'

  belongs_to :mlab_encounter, foreign_key: 'encounter_id', class_name: 'MlabEncounter'
  belongs_to :mlab_priority, foreign_key: 'priority_id', class_name: 'MlabPriority', optional: true
  belongs_to :mlab_status, foreign_key: 'status_id', class_name: 'MlabStatus', optional: true
  has_many :mlab_tests, foreign_key: 'order_id', class_name: 'MlabTest'
  has_many :mlab_order_statuses, foreign_key: 'order_id', class_name: 'MlabOrderStatus'

  scope :not_voided, -> { where('orders.voided IS NULL OR orders.voided = 0') }
end
