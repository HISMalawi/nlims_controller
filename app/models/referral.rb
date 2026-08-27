# frozen_string_literal: true

# One sample handed from one laboratory to another.
#
# Referral is not a status of the order but a record of its own, because the
# order has one lifecycle and the parcel has another: a sample can be dispatched
# and never arrive, and the difference between those two facts is what an
# investigation turns on.
class Referral < ApplicationRecord
  include HasUuid
  include DictionaryTerms

  DISPATCHED = "dispatched"
  RECEIVED = "received"
  REJECTED = "rejected"

  STATE_MACHINE = StatusMachine.new(
    initial: DISPATCHED,
    transitions: { DISPATCHED => [ RECEIVED, REJECTED ] }
  )

  class AlreadySettled < StandardError; end

  belongs_to :order

  dictionary_term :rejection_reason, entity: "rejection_reasons", name: :rejection_name, code: :rejection_code

  # Set when this referral is a copy of one dispatched by another node, so the
  # receiving node stores it without re-announcing it.
  attr_accessor :replicated

  validates :tracking_number, :to_lab_code, presence: true
  validates :state, inclusion: { in: STATE_MACHINE.statuses }
  validate :destination_is_not_the_origin

  after_create :announce_dispatch

  scope :outstanding, -> { where(state: DISPATCHED) }
  scope :for_node, ->(lab_code) { where(to_lab_code: lab_code) }

  # The sample leaves first and the parcel is announced second, and the order
  # matters: until the referral exists the sample concerns nobody but this
  # facility, so the move to referred_out is nobody else's business. Announced
  # the other way round, the receiving laboratory would be told the sample had
  # arrived and then told it was on its way out again — its own copy overwritten
  # by the origin's view of it.
  # The destination, as the register describes it. The client sends a laboratory
  # code and nothing else: the health facility, and the name that goes in the
  # history, are things the national register already published to this node.
  #
  # A code the register does not carry is refused — but only once the register
  # has been pulled at all. On a node that has never received one, refusing
  # would be blaming the client for something missing at this end.
  def self.resolve_destination!(to_lab_code)
    code = to_lab_code.presence
    raise InvalidRequest.new("é preciso indicar o laboratório de destino", field: "to_lab_code") if code.nil?

    lab = Lab.find_by(national_code: code)

    if lab.nil? && Lab.exists?
      raise InvalidRequest.new("o laboratório #{code} não consta do registo nacional deste nó",
                               field: "to_lab_code")
    end

    { lab_code: code, facility_code: lab&.facility, label: lab&.label || code }
  end

  def self.dispatch!(order:, to_lab_code:, courier: nil, remarks: nil, actor: nil)
    destination = resolve_destination!(to_lab_code)

    transaction do
      order.transition_to!(Order::REFERRED_OUT, actor: actor,
                                                reason: "referida para #{destination[:label]}")

      create!(
        order: order,
        tracking_number: order.tracking_number,
        from_facility_code: order.sending_facility_code,
        from_lab_code: order.receiving_lab_code,
        to_facility_code: destination[:facility_code],
        to_lab_code: destination[:lab_code],
        courier: courier,
        remarks: remarks,
        dispatched_at: Time.current
      )
    end
  end

  # The sample physically arrived.
  #
  # Only the copy the receiving laboratory holds becomes its work. On the node
  # that sent the sample the order stays referred_out — it is still away, and it
  # comes back as a result rather than as a change of hands.
  def receive!(actor: nil, remarks: nil)
    settle!(RECEIVED, actor: actor, remarks: remarks) do
      self.received_at = Time.current

      if order.status == Order::REFERRED_IN
        order.transition_to!(Order::ACCEPTED, actor: actor, reason: "amostra referida recebida em #{to_lab_code}")
      end
    end
  end

  # It arrived broken, warm, or not at all. The order is refused with the reason
  # the receiving laboratory gave, and the origin learns why.
  def reject!(reason:, actor: nil, remarks: nil)
    reference = reason.is_a?(Dictionary::Reference) ? reason : Dictionary::Reference.resolve("rejection_reasons", reason)

    settle!(REJECTED, actor: actor, remarks: remarks) do
      self.rejected_at = Time.current
      self.rejection_reason_reference = reference
      order.reject!(reason: reference, actor: actor, note: remarks)
    end
  end

  # Where this sample went, as the register describes it — nil for a code the
  # register has not caught up with, which is what the stored codes are for.
  def destination
    @destination ||= Lab.find_by(national_code: to_lab_code)
  end

  def destination_label
    destination&.label || to_lab_code
  end

  def dispatched? = state == DISPATCHED
  def received? = state == RECEIVED
  def rejected? = state == REJECTED
  def settled? = !dispatched?

  # What a laboratory waiting for a parcel wants to know, and what nobody can
  # currently measure.
  def transport_time
    return nil if received_at.blank?

    received_at - dispatched_at
  end

  private

  def settle!(state, actor:, remarks:)
    raise AlreadySettled, "#{tracking_number} já foi #{self.state}" if settled?

    self.class.transaction do
      self.state = state
      self.remarks = [ self.remarks, remarks ].compact_blank.join(" — ") if remarks.present?
      yield
      save!
      announce(state == RECEIVED ? OutboxEvent::REFERRAL_RECEIVED : OutboxEvent::REFERRAL_REJECTED, actor: actor)
    end

    self
  end

  # The dispatch carries the whole order: the receiving node has never heard of
  # this sample, and cannot be asked to accept a referral for something it does
  # not have.
  def announce_dispatch
    return if replicated

    announce(OutboxEvent::REFERRAL_DISPATCHED, detail: { order: OrderSerializer.call(order.class.find(order.id)) })
  end

  def announce(type, detail: {}, actor: nil)
    OutboxEvent.record!(
      type: type,
      aggregate_uuid: order.uuid,
      payload: { referral: ReferralSerializer.call(self), actor: actor }.merge(detail)
    )
  end

  def destination_is_not_the_origin
    return if to_lab_code.blank?
    return unless to_lab_code == from_lab_code

    errors.add(:to_lab_code, "a sample cannot be referred to the laboratory that already has it")
  end
end
