# frozen_string_literal: true

module SislabSyncClient
  # What a SISLAB installation calls: take the work, do it, publish it.
  #
  # The laboratory polls and publishes; the node never calls the laboratory.
  # That is what lets a SISLAB sit behind a router nobody administers, which is
  # where most of them sit — so there is no callback to register here, and
  # nothing in this profile needs an address of its own.
  class Lab < Profile
    # Everything for this laboratory that changed since the cursor — not only
    # what is still open. An order cancelled at the clinic after the laboratory
    # took it is exactly what the laboratory has to be told about, and a feed
    # that hid it would leave a sample being worked on that nobody wants.
    def pending_orders(since: 0, lab_code: nil, limit: nil)
      params = lab_code ? { lab_code: lab_code } : {}

      Feed.new(connection, "/api/v3/lab/pending-orders", params, since: since, limit: limit)
    end

    # Takes the sample. Two laboratories claiming the same one is settled by the
    # node: the first wins, the second gets Conflict and knows at once that it
    # is not theirs, rather than both working it up.
    def claim(tracking_number)
      connection.post("/api/v3/lab/orders/#{escape(tracking_number)}/claim").data
    end

    # Moves the sample on. A transition the state machine does not allow is
    # refused before anything is written, and arrives as Unprocessable.
    #
    # `actor` is the technician where the laboratory names one: the key
    # identifies the installation, not the person who read the slide.
    def transition(tracking_number, status:, reason: nil, actor: nil)
      body = { status: status, reason: reason, actor: actor }.compact

      connection.patch("/api/v3/lab/orders/#{escape(tracking_number)}/status", body).data
    end

    # Publishes readings. `final: true` closes the tests these readings belong
    # to; without it the laboratory is publishing what it has so far and is
    # still working.
    #
    # A correction is a new reading on a test that stays completed — send it the
    # same way, and the node marks the old one replaced.
    def record_results(tracking_number, results:, final: false, actor: nil)
      body = {
        final: final,
        actor: actor,
        results: Array(results).map { |result| normalise_result(result) }
      }.compact

      connection.post("/api/v3/lab/orders/#{escape(tracking_number)}/results", body).data
    end

    # A test the clinician did not ask for but the laboratory ran anyway — a
    # confirmation, a reflex test. It goes on the sample already drawn, under
    # the tracking number the clinic is already waiting on, rather than becoming
    # a second order nobody at the clinic recognises.
    def add_tests(tracking_number, tests:, actor: nil)
      body = {
        actor: actor,
        tests: Array(tests).map { |test| normalise_added_test(test) }
      }.compact

      connection.post("/api/v3/lab/orders/#{escape(tracking_number)}/tests", body).data
    end

    # Refuses the sample — hemolysed, underfilled, unlabelled. The reason comes
    # from the `rejection_reasons` dictionary and not from free text: the clinic
    # that has to draw again needs a reason that means the same thing
    # everywhere.
    def reject(tracking_number, reason:, note: nil, actor: nil)
      body = { reason: reference(reason, :reason), note: note, actor: actor }.compact

      connection.post("/api/v3/lab/orders/#{escape(tracking_number)}/reject", body).data
    end

    # Sends the sample to a laboratory that can run what this one cannot today.
    # It travels under the same tracking number, and the result comes back under
    # it whichever laboratory produced it.
    def dispatch_referral(tracking_number:, to_facility_code:, to_lab_code:,
                          courier: nil, remarks: nil, actor: nil)
      body = {
        tracking_number: tracking_number,
        to_facility_code: to_facility_code,
        to_lab_code: to_lab_code,
        courier: courier,
        remarks: remarks,
        actor: actor
      }.compact

      connection.post("/api/v3/lab/referrals", body).data
    end

    # The receiving laboratory says the parcel arrived. Only it can: anything
    # else would be a guess about a sample nobody has looked at.
    def receive_referral(uuid, remarks: nil, actor: nil)
      settle_referral(uuid, state: "received", remarks: remarks, actor: actor)
    end

    # The receiving laboratory refuses the parcel, with a reason from the
    # dictionary.
    def reject_referral(uuid, reason:, remarks: nil, actor: nil)
      settle_referral(uuid, state: "rejected", reason: reason, remarks: remarks, actor: actor)
    end

    private

    def settle_referral(uuid, state:, reason: nil, remarks: nil, actor: nil)
      body = {
        state: state,
        reason: reference(reason, :reason),
        remarks: remarks,
        actor: actor
      }.compact

      connection.patch("/api/v3/lab/referrals/#{escape(uuid)}", body).data
    end

    def normalise_result(result)
      result = result.transform_keys(&:to_sym)

      result.merge(
        test_type: reference(result[:test_type], :test_type),
        indicator: reference(result[:indicator], :indicator)
      ).compact
    end

    def normalise_added_test(test)
      return { test_type: reference(test, :test_type) } if test.is_a?(String)

      test = test.transform_keys(&:to_sym)
      test.merge(test_type: reference(test[:test_type], :test_type)).compact
    end
  end
end
