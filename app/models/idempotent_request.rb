# frozen_string_literal: true

# The stored answer to a request that has already been processed. A client whose
# connection dropped mid-write can safely send the same request again and get
# the original response back, with the original status.
class IdempotentRequest < ApplicationRecord
  belongs_to :api_client

  validates :idempotency_key, presence: true, length: { maximum: 255 }

  def self.digest_for(body)
    Digest::SHA256.hexdigest(body.to_s)
  end

  def replays?(request_digest)
    self.request_digest == request_digest
  end
end
