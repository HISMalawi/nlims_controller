# frozen_string_literal: true

module SislabSyncClient
  # Every refusal a node can give, as a class.
  #
  # The node's `code` is the contract and does not change; its `message` is
  # Portuguese written for a person and may be reworded at any time. So the code
  # picks the class and the message is only ever shown, never matched on — which
  # is the rule this library exists to make it easy to follow.
  class Error < StandardError
    attr_reader :code, :field, :status, :body

    def initialize(message, code: nil, field: nil, status: nil, body: nil)
      super(message)
      @code = code
      @field = field
      @status = status
      @body = body
    end
  end

  # The node could not be reached, or did not answer in a way that could be
  # read. Distinct from every other error here: nothing is known about whether
  # the work happened, which is why retrying is only safe where the request
  # carried an Idempotency-Key.
  class TransportError < Error; end

  class Unauthenticated < Error; end
  class InsufficientScope < Error; end
  # A key acting for a node other than its own.
  class LabMismatch < Error; end
  class IdempotencyKeyRequired < Error; end
  class IdempotencyKeyReused < Error; end
  class NotFound < Error; end
  class Conflict < Error; end
  class Unprocessable < Error; end

  # The key has spent its allowance for this minute. `retry_after` is how long
  # the node said to wait; the connection honours it on its own unless retries
  # have been turned off.
  class RateLimited < Error
    attr_reader :retry_after

    def initialize(message, retry_after: nil, **options)
      super(message, **options)
      @retry_after = retry_after
    end
  end

  # An answer that is not in the contract at all. Reaching this means the node
  # is running something this library has not been taught about.
  class UnexpectedResponse < Error; end

  # A feed that claims to have more but hands back a cursor that has not moved.
  # Raised rather than spun on: a client looping against a laboratory's node is
  # worse than a client that stops and says why.
  class FeedStalled < Error; end

  ERRORS = {
    "unauthenticated" => Unauthenticated,
    "insufficient_scope" => InsufficientScope,
    "lab_mismatch" => LabMismatch,
    "idempotency_key_required" => IdempotencyKeyRequired,
    "idempotency_key_reused" => IdempotencyKeyReused,
    "rate_limited" => RateLimited,
    "not_found" => NotFound,
    "conflict" => Conflict,
    "unprocessable" => Unprocessable
  }.freeze

  def self.error_for(code)
    ERRORS.fetch(code, UnexpectedResponse)
  end
end
