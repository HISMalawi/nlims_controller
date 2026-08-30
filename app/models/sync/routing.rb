# frozen_string_literal: true

module Sync
  # Who else needs to know.
  #
  # A referred sample concerns two facilities at once: the one that took it and
  # the one running the test. Neither can see the other — they talk to the
  # capital, not to each other — so the national node works out who is
  # interested in each event as it applies it.
  #
  # The sender is never told its own news back. Without that, two nodes holding
  # one sample would push each other's events round for ever.
  class Routing
    def self.fan_out(event)
      new(event).call
    end

    def initialize(event)
      @event = event
    end

    def call
      interested.each { |node_code| InboundDelivery.queue!(node_code, @event) }
    end

    private

    # Everyone with a hand on this sample: the unit that took it, and every unit
    # it has been referred to.
    #
    # By health facility code, because that is what a node answers to. An mLab
    # instance holds several laboratories behind one node, and addressing a
    # parcel to one of them would leave it queued for a node that does not
    # exist — the node is the unit, and it hands the sample to the right bench
    # itself, by the referral's `to_lab_code`.
    #
    # An event that belongs to no sample — a laboratory registering itself —
    # concerns nobody but the capital, and reaches the other nodes down the
    # dictionary feed rather than as a parcel.
    def interested
      order = Order.find_by(uuid: @event.aggregate_uuid)
      return [] if order.nil?

      codes = [ order.receiving_facility_code ]
      codes += Referral.where(order_id: order.id).pluck(:to_facility_code)

      codes.compact.uniq - [ @event.node_code ]
    end
  end
end
