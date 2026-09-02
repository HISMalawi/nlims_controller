# frozen_string_literal: true

module Sync
  # Turns one event from a local node into the national node's copy.
  #
  # The state machines are not enforced here. They are enforced where the change
  # was made; a replica that refused a state the node of record had already
  # committed would disagree with it for ever, and would do so silently. What is
  # enforced instead is order: an event is only applied when its predecessor
  # already has been.
  class Applier
    def initialize(event)
      @event = event
      @payload = event.payload || {}
    end

    def apply!
      case @event.type
      when OutboxEvent::PATIENT_UPSERTED then upsert_patient
      when OutboxEvent::ORDER_CREATED then create_order
      when OutboxEvent::ORDER_STATUS_CHANGED, OutboxEvent::SPECIMEN_REJECTED then change_order_status
      when OutboxEvent::ORDER_TEST_ADDED then add_test
      when OutboxEvent::TEST_STATUS_CHANGED then change_test_status
      when OutboxEvent::TEST_RESULT_RECORDED then record_result
      when OutboxEvent::REFERRAL_DISPATCHED then dispatch_referral
      when OutboxEvent::REFERRAL_RECEIVED, OutboxEvent::REFERRAL_REJECTED then settle_referral
      when OutboxEvent::LAB_REGISTERED then register_lab
      else
        raise Rejected.new(Rejected::UNKNOWN_TYPE, "#{@event.type} is not an event this node knows")
      end
    end

    private

    def upsert_patient
      patient = Patient.find_or_initialize_by(uuid: @payload["uuid"])
      patient.assign_attributes(patient_attributes(@payload))
      patient.save!
      patient
    end

    def patient_attributes(json)
      {
        national_id: json["national_id"],
        name: json["name"],
        sex: json["sex"].presence || "Unknown",
        birthdate: json["birthdate"],
        phone: json["phone"]
      }.compact
    end

    # The order carries its patient, so a sample can be applied for someone the
    # national node has never heard of. Waiting for patient.upserted to arrive
    # first would mean ordering two aggregates against each other, which the
    # per-aggregate sequence deliberately does not do.
    def create_order(json = nil, status: nil)
      json ||= @payload.fetch("order") { raise Rejected.new(Rejected::MALFORMED, "order.created carries no order") }
      order = Order.find_or_initialize_by(uuid: json["uuid"])
      return order if order.persisted?

      # A sample arriving from another unit carries the unit and the bench that
      # sent it away, and neither of them is this node's. Which laboratory here
      # takes it is settled when the parcel is opened, so it arrives against
      # none of them: written down, the origin's code would file the sample
      # under a laboratory that does not exist at this unit, and hide it from
      # the feed of every laboratory that does.
      arriving = status == Order::REFERRED_IN

      order.assign_attributes(
        tracking_number: json["tracking_number"],
        patient: upsert_patient_from(json["patient"]),
        status: status || json["status"],
        priority: json["priority"],
        sending_facility_code: json["sending_facility_code"],
        receiving_facility_code: receiving_facility_for(json, arriving),
        receiving_lab_code: arriving ? nil : json["receiving_lab_code"],
        lab_code: json["lab_code"],
        collected_at: json["collected_at"],
        requested_by: json["requested_by"],
        order_location: json["order_location"],
        clinical_history: json["clinical_history"],
        source_system: json["source_system"],
        replicated: true,
        status_actor: actor,
        status_reason: reason
      )
      order.specimen_type_reference = term(json["specimen_type"], "specimen_types")

      order.save!

      # A referred sample arrives with its tests already on it: the node
      # receiving it was not there when they were added, and will never be sent
      # those events, because they happened before it had anything to do with
      # the sample.
      Array(json["tests"]).each { |test| upsert_test(order, test) }

      order
    end

    # The unit holding the sample, which is what a laboratory polls by
    # (`Order.for_facility`) and what every /lab/ route authorises against.
    #
    # On the node a sample was referred to, that unit is this one. Copied across
    # as it arrived it would be the unit that sent the sample away, and the
    # parcel would land on a node where no bench can see it and no bench is
    # allowed to touch it: the order reaches the destination, the destination's
    # LIS polls a feed that filters it out, and the sample sits in a database
    # nobody is looking at. Which is the only shape a referral can fail in that
    # looks, from both ends, like it worked.
    #
    # Only on the node that receives it. The capital keeps the unit the origin
    # gave, because from there the sample is simply out — and that is also what
    # `Sync::Routing` reads to know which nodes still have a hand on it.
    def receiving_facility_for(json, arriving)
      return SislabSync.facility_code if arriving

      json["receiving_facility_code"].presence || json["sending_facility_code"]
    end

    def upsert_test(order, json)
      order_test = OrderTest.find_or_initialize_by(uuid: json["uuid"])
      return order_test if order_test.persisted?

      order_test.assign_attributes(
        order: order,
        status: json["status"],
        method_of_testing: json["method_of_testing"],
        replicated: true,
        status_actor: actor
      )
      order_test.test_type_reference = term(json["test_type"], "test_types")
      order_test.test_panel_reference = term(json["test_panel"], "test_panels")

      order_test.save!
      order_test
    end

    def upsert_patient_from(json)
      raise Rejected.new(Rejected::MALFORMED, "the order carries no patient") if json.blank?

      patient = Patient.find_or_initialize_by(uuid: json["uuid"])
      patient.assign_attributes(patient_attributes(json))
      patient.save!
      patient
    end

    def change_order_status
      order = find_order!
      order.rejection_reason_reference = term(@payload["rejection_reason"], "rejection_reasons") if
        @event.type == OutboxEvent::SPECIMEN_REJECTED

      apply_status(order)
    end

    def add_test
      json = @payload.fetch("test") { raise Rejected.new(Rejected::MALFORMED, "order.test_added carries no test") }

      upsert_test(find_order!, json)
    end

    # The sample is on its way here, or on its way somewhere this node has an
    # interest in. Either way the order comes with it, because the receiving
    # node has never heard of this sample and cannot be asked to accept a parcel
    # for something it does not have.
    def dispatch_referral
      json = referral_json
      order = create_order(@payload["order"], status: arriving_here?(json) ? Order::REFERRED_IN : nil)

      referral = Referral.find_or_initialize_by(uuid: json["uuid"])
      return referral if referral.persisted?

      referral.assign_attributes(
        order: order,
        tracking_number: json["tracking_number"],
        from_facility_code: json["from_facility_code"],
        from_lab_code: json["from_lab_code"],
        to_facility_code: json["to_facility_code"],
        to_lab_code: json["to_lab_code"],
        state: json["state"],
        dispatched_at: json["dispatched_at"],
        courier: json["courier"],
        remarks: json["remarks"],
        replicated: true
      )

      referral.save!
      referral
    end

    def settle_referral
      json = referral_json
      referral = Referral.find_by(uuid: json["uuid"]) ||
                 raise(Rejected.new(Rejected::UNKNOWN_AGGREGATE, "this node has no referral #{json['uuid']}"))

      referral.rejection_reason_reference = term(json["rejection_reason"], "rejection_reasons")
      referral.update!(
        state: json["state"],
        received_at: json["received_at"],
        rejected_at: json["rejected_at"],
        remarks: json["remarks"]
      )

      hand_over_internally(referral) if referral.received? && referral.internal?

      referral
    end

    # A handover between two benches of one unit never leaves the node that
    # holds it, so there is no second copy of the order to send and no status to
    # change — only the fact that the work is now the other laboratory's. The
    # capital would otherwise go on naming the bench that first took the sample
    # as the one that ran it.
    def hand_over_internally(referral)
      referral.order.update!(receiving_lab_code: referral.to_lab_code,
                             claimed_by_lab_code: referral.to_lab_code)
    end

    def referral_json
      @payload.fetch("referral") { raise Rejected.new(Rejected::MALFORMED, "the event carries no referral") }
    end

    # A local node that is the destination holds the sample as referred_in: it
    # is work arriving, not work sent away. The national node keeps the status
    # the origin gave it, because from the capital the sample is simply out.
    #
    # By unit, not by laboratory: the node is the unit, and the parcel is for it
    # whichever of its benches ends up opening it.
    def arriving_here?(json)
      SislabSync.local? && json["to_facility_code"] == SislabSync.facility_code
    end

    # A laboratory a node met for the first time, given the code the country
    # will know it by.
    #
    # Accepted as it stands and published at once, with no approval step: a
    # laboratory that has already taken a sample exists whether or not anybody
    # in the capital has looked at it, and a duplicate in the register costs an
    # afternoon's tidying where a queue costs a laboratory nobody can refer to.
    #
    # Matched on the uuid the node sent, and failing that on the pair the
    # register is keyed by, so a node that registered a laboratory and was then
    # rebuilt does not create a second entry for it.
    def register_lab
      lab = Lab.find_by(uuid: @payload["uuid"]) ||
            Lab.find_by(facility_code: @payload["facility_code"], source_code: @payload["source_code"]) ||
            Lab.new(uuid: @payload["uuid"])

      lab.assign_attributes(
        facility_code: @payload["facility_code"],
        source_code: @payload["source_code"],
        name: @payload["name"].presence || @payload["source_code"],
        short_name: @payload["short_name"],
        description: @payload["description"],
        phone: @payload["phone"]
      )
      lab.status = DictionaryEntry::ACTIVE unless lab.retired?
      lab.status_actor = actor
      lab.status_reason = "registado por #{@event.node_code}"
      lab.save!

      lab
    end

    def change_test_status
      apply_status(find_test!)
    end

    def record_result
      order_test = find_test_by_uuid!(@payload["order_test_uuid"])
      return if TestResult.exists?(uuid: @payload["uuid"])

      result = TestResult.new(
        uuid: @payload["uuid"],
        order_test: order_test,
        value: @payload["value"],
        unit: @payload["unit"],
        recorded_at: @payload["recorded_at"],
        recorded_by: @payload["recorded_by"]
      )
      result.indicator_reference = term(@payload["indicator"], "indicators")
      result.save!

      # The readings this one corrects were marked on the node that recorded it,
      # and the event says which they were.
      Array(@payload["replaces"]).each do |uuid|
        TestResult.find_by(uuid: uuid)&.update!(replaced_by_uuid: result.uuid)
      end

      result
    end

    def apply_status(record)
      record.replicated = true
      record.status_actor = actor
      record.status_reason = reason
      record.status = @payload["to_status"]
      record.save!
      record
    end

    def find_order!
      Order.find_by(uuid: @event.aggregate_uuid) ||
        raise(Rejected.new(Rejected::UNKNOWN_AGGREGATE,
                           "this node has no order #{@event.aggregate_uuid}"))
    end

    def find_test!
      find_test_by_uuid!(@payload["entity_uuid"])
    end

    def find_test_by_uuid!(uuid)
      OrderTest.find_by(uuid: uuid) ||
        raise(Rejected.new(Rejected::UNKNOWN_AGGREGATE, "this node has no test #{uuid}"))
    end

    # A term as it arrived, linked to this node's dictionary where it can be.
    #
    # A term the receiving node does not carry is stored, not refused. Local
    # nodes order exams the national catalogue has not reached, a reading
    # refused in the capital is a reading lost, and refusing the event
    # (UNKNOWN_DICTIONARY_ITEM) would block that node's whole stream until
    # somebody noticed. The name travels with the code, so the national node
    # stores what was measured either way and can link it when the catalogue
    # catches up.
    def term(json, entity_type)
      Dictionary::Reference.resolve(entity_type, json)
    end

    def actor
      @payload["actor"].presence || "node:#{@event.node_code}"
    end

    def reason
      @payload["reason"]
    end
  end
end
