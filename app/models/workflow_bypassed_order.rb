# frozen_string_literal: true

# A sample that was processed without going through the order workflow, logged by tracking number
class WorkflowBypassedOrder < ApplicationRecord
  validates :tracking_number, :ordered_at, :specimen_type, :test_type, :ordering_facility, presence: true
  validates :tracking_number, uniqueness: true
end
