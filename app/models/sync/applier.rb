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
    def create_order
      json = @payload.fetch("order") { raise Rejected.new(Rejected::MALFORMED, "order.created carries no order") }
      order = Order.find_or_initialize_by(uuid: json["uuid"])
      return order if order.persisted?

      order.assign_attributes(
        tracking_number: json["tracking_number"],
        patient: upsert_patient_from(json["patient"]),
        specimen_type: dictionary(SpecimenType, json["specimen_type"], "specimen_type"),
        status: json["status"],
        priority: json["priority"],
        sending_facility_code: json["sending_facility_code"],
        receiving_lab_code: json["receiving_lab_code"],
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

      order.save!
      order
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
      order.rejection_reason = dictionary(RejectionReason, @payload["rejection_reason"], "rejection_reason") if
        @event.type == OutboxEvent::SPECIMEN_REJECTED

      apply_status(order)
    end

    def add_test
      json = @payload.fetch("test") { raise Rejected.new(Rejected::MALFORMED, "order.test_added carries no test") }
      order = find_order!

      order_test = OrderTest.find_or_initialize_by(uuid: json["uuid"])
      return order_test if order_test.persisted?

      order_test.assign_attributes(
        order: order,
        test_type: dictionary!(TestType, json["test_type"], "test_type"),
        test_panel: dictionary(TestPanel, json["test_panel"], "test_panel"),
        status: json["status"],
        method_of_testing: json["method_of_testing"],
        replicated: true,
        status_actor: actor
      )

      order_test.save!
      order_test
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
        indicator: dictionary!(Indicator, @payload["indicator"], "indicator"),
        value: @payload["value"],
        unit: @payload["unit"],
        recorded_at: @payload["recorded_at"],
        recorded_by: @payload["recorded_by"]
      )
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

    def dictionary(model, reference, field)
      return nil if reference.blank?

      dictionary!(model, reference, field)
    end

    # A code the national dictionary does not have is the one rejection the plan
    # names by example, and it is a real one: a node running an older dictionary
    # can order a test that has since been retired and renumbered.
    def dictionary!(model, reference, field)
      raise Rejected.new(Rejected::MALFORMED, "#{field} is missing") if reference.blank?

      entry = model.find_by(uuid: reference["uuid"]) ||
              model.find_by(national_code: reference["national_code"])

      entry || raise(Rejected.new(
                       Rejected::UNKNOWN_DICTIONARY_ITEM,
                       "#{field} #{reference['national_code'] || reference['uuid']} is not in this node's dictionary"
                     ))
    end

    def actor
      @payload["actor"].presence || "node:#{@event.node_code}"
    end

    def reason
      @payload["reason"]
    end
  end
end
