# frozen_string_literal: true

module Api
  # The error codes clients are allowed to depend on. Messages are for people
  # and may be reworded or translated; codes are a contract and may not.
  module Errors
    UNAUTHENTICATED = "unauthenticated"
    INSUFFICIENT_SCOPE = "insufficient_scope"
    # A key acting for a node other than its own. There is no facility
    # equivalent: a node is a health facility, so a request never names a
    # facility this node could disagree with.
    NODE_MISMATCH = "node_mismatch"
    IDEMPOTENCY_KEY_REQUIRED = "idempotency_key_required"
    IDEMPOTENCY_KEY_REUSED = "idempotency_key_reused"
    RATE_LIMITED = "rate_limited"
    NOT_FOUND = "not_found"
    CONFLICT = "conflict"
    UNPROCESSABLE = "unprocessable"

    STATUSES = {
      UNAUTHENTICATED => :unauthorized,
      INSUFFICIENT_SCOPE => :forbidden,
      NODE_MISMATCH => :forbidden,
      IDEMPOTENCY_KEY_REQUIRED => :bad_request,
      IDEMPOTENCY_KEY_REUSED => :unprocessable_content,
      RATE_LIMITED => :too_many_requests,
      NOT_FOUND => :not_found,
      CONFLICT => :conflict,
      UNPROCESSABLE => :unprocessable_content
    }.freeze

    def self.status_for(code)
      STATUSES.fetch(code, :unprocessable_content)
    end

    def self.message_for(code)
      I18n.t("api.errors.#{code}", default: code.tr("_", " "))
    end
  end
end
