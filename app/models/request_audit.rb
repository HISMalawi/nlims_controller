# frozen_string_literal: true

# One row per API request, accepted or rejected. Answers "who called what, when,
# from where, and what did they get" without reading application logs.
class RequestAudit < ApplicationRecord
  belongs_to :api_client, optional: true
  belongs_to :api_key, optional: true

  scope :rejected, -> { where.not(error_code: nil) }
  scope :recent, -> { order(created_at: :desc) }
end
