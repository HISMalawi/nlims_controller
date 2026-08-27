# frozen_string_literal: true

module SislabSyncClient
  # What a clinical system calls: ask for tests, then collect results.
  #
  #   emr = SislabSyncClient::Emr.new(base_url: "http://localhost:3000", api_key: ENV["SISLAB_KEY"])
  #
  #   receipt = emr.create_order(
  #     patient: { national_id: "1234567890", name: "Ana Chirindza", sex: "F", birthdate: "1988-04-02" },
  #     order: { sending_facility_code: "HCM", receiving_lab_code: "HCM-LAB", priority: "routine" },
  #     tests: [ { test_type: "HEM001" } ]
  #   )
  #
  #   receipt["tracking_number"] # => the number written on the tube
  class Emr < Profile
    # Asks for tests and answers a receipt: the tracking number, the order's
    # uuid, and the status it starts in. Everything else about the order is one
    # `order` call away.
    #
    # An `Idempotency-Key` is generated unless one is given, and it is the whole
    # reason this is safe to retry. The networks between a clinic and its
    # laboratory drop mid-request; without the key, a retry is a second sample
    # nobody drew. Pass your own where you have an identifier of your own for
    # the request — then even a retry from a fresh process is recognised.
    def create_order(patient:, order:, tests:, idempotency_key: nil)
      body = {
        patient: patient,
        order: normalise_order(order),
        tests: Array(tests).map { |test| normalise_test(test) }
      }

      connection.post("/api/v3/order-requests", body,
                      idempotency_key: idempotency_key || SecureRandom.uuid).data
    end

    # One sample, by the number written on the tube. Without the readings: a
    # client following where a sample has got to does not want every value.
    def order(tracking_number)
      connection.get("/api/v3/orders/#{escape(tracking_number)}").data
    end

    # The same sample with the readings inside each test. Superseded readings
    # travel too, so a client that filed a value that was later corrected can
    # see that it was, and by which row.
    def order_results(tracking_number)
      connection.get("/api/v3/orders/#{escape(tracking_number)}/results").data
    end

    # Everything new for this facility since the cursor, without having to ask
    # after each order ever raised. Each reading carries the context it would
    # otherwise take a second call to find: the sample, the patient, the test.
    #
    #   feed = emr.results(since: stored_cursor)
    #   feed.each_page do |readings, cursor|
    #     readings.each { |reading| file(reading) }
    #     store(cursor)
    #   end
    def results(since: 0, patient_national_id: nil, limit: nil)
      params = patient_national_id ? { patient_national_id: patient_national_id } : {}

      Feed.new(connection, "/api/v3/results", params, since: since, limit: limit)
    end

    # Says this reading reached the patient's record. It is what lets a
    # laboratory tell a critical result that was seen from one sitting in a
    # queue.
    #
    # A reading that has since been corrected is refused with Conflict, and the
    # error names its replacement — filing a superseded value is the mistake the
    # whole `replaced_by_uuid` design exists to prevent.
    def acknowledge(uuid)
      connection.post("/api/v3/results/#{escape(uuid)}/acknowledge").data
    end

    private

    # `specimen_type` takes a bare national code like everything else that
    # points at the dictionary. Sending the bare string on the wire would be
    # dropped by the node's strong parameters and the order would be created
    # with no specimen type at all — quietly, which is the worst way to lose a
    # field.
    def normalise_order(order)
      order = order.transform_keys(&:to_sym)
      return order unless order.key?(:specimen_type)

      order.merge(specimen_type: reference(order[:specimen_type], :specimen_type))
    end

    # A test may be asked for by code, or as a hash for anything more. Both
    # `test_type` and `test_panel` take a bare national code or name — a panel expands
    # into the tests that make it up.
    def normalise_test(test)
      return { test_type: reference(test, :test_type) } if test.is_a?(String)

      test = test.transform_keys(&:to_sym)
      test.merge(
        test_type: reference(test[:test_type], :test_type),
        test_panel: reference(test[:test_panel], :test_panel)
      ).compact
    end
  end
end
