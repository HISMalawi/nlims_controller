# frozen_string_literal: true

module Api
  # Networks between a facility and its laboratory drop mid-request. A client
  # that retries must not create a second order, so every creating endpoint
  # requires an Idempotency-Key and replays the first answer verbatim.
  #
  # Used as a guard around the action body:
  #
  #   def create
  #     idempotent do
  #       ...
  #       render_data(...)
  #     end
  #   end
  module Idempotency
    extend ActiveSupport::Concern

    private

    # `key` is the header unless the caller has something better. The FHIR
    # façade passes the placer order number the EMR already put on the request,
    # so a client that has never heard of this header still retries safely.
    def idempotent(key: request.headers["Idempotency-Key"].presence)
      return render_api_error(Errors::IDEMPOTENCY_KEY_REQUIRED) if key.blank?

      digest = IdempotentRequest.digest_for(request.raw_post)
      existing = IdempotentRequest.find_by(api_client: Current.api_client, idempotency_key: key)

      if existing
        # Same key, different body: the client has a bug, and replaying the old
        # answer would hide it.
        return render_api_error(Errors::IDEMPOTENCY_KEY_REUSED) unless existing.replays?(digest)

        return replay(existing)
      end

      yield

      record_idempotent_response(key, digest)
    end

    def replay(existing)
      response.headers["Idempotent-Replay"] = "true"
      render json: existing.response_body, status: existing.response_status
    end

    def record_idempotent_response(key, digest)
      return unless response.successful?

      IdempotentRequest.create!(
        api_client: Current.api_client,
        idempotency_key: key,
        endpoint: "#{request.request_method} #{request.path}",
        request_digest: digest,
        response_status: response.status,
        response_body: response.body
      )
    rescue ActiveRecord::RecordNotUnique
      # Two retries raced. Both did the same work; the stored answer stands.
      nil
    end
  end
end
