# frozen_string_literal: true

# MlabSyncFailure model to track failed mlab to nlims sync operations
class MlabSyncFailure < ApplicationRecord
  validates :mlab_test_id, presence: true
  validates :failure_stage, presence: true
  validates :failure_reason, presence: true

  scope :unresolved, -> { where(resolved: false) }
  scope :resolved, -> { where(resolved: true) }
  scope :by_stage, ->(stage) { where(failure_stage: stage) }
  scope :recent, -> { order(created_at: :desc) }

  def mark_resolved!(user_id, notes = nil)
    update!(
      resolved: true,
      resolved_at: Time.current,
      resolved_by: user_id,
      resolution_notes: notes
    )
  end

  def increment_retry!
    update!(
      retry_count: retry_count + 1,
      last_retry_at: Time.current
    )
  end

  def self.log_failure(mlab_test_id:, stage:, reason:, tracking_number: nil, test_type_nlims_code: nil, site_name: nil, payload: nil)
    create!(
      mlab_test_id: mlab_test_id,
      tracking_number: tracking_number,
      test_type_nlims_code: test_type_nlims_code,
      site_name: site_name,
      failure_stage: stage,
      failure_reason: reason,
      payload_snapshot: payload&.to_json
    )
  end
end
