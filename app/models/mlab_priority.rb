# frozen_string_literal: true

# MlabPriority model - reads from mlab database priorities table
class MlabPriority < MlabBase
  self.table_name = 'priorities'

  has_many :mlab_orders, foreign_key: 'priority_id', class_name: 'MlabOrder'

  scope :not_retired, -> { where('retired IS NULL OR retired = 0') }
end
