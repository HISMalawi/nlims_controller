# frozen_string_literal: true

# Samples handed to another laboratory, and samples handed to this one.
#
# The screen is here for the number nobody can currently measure: how long a
# parcel takes between two laboratories, and how many never arrive at all.
class ReferralsController < ApplicationController
  STATES = [ Referral::DISPATCHED, Referral::RECEIVED, Referral::REJECTED ].freeze

  DIRECTIONS = %w[out in].freeze

  PER_PAGE = 50

  def index
    @state = params[:state].presence_in(STATES)

    # "Sent from here" and "arriving here" only mean something at a facility.
    # The national node holds no samples of its own; it sees every referral in
    # the country and neither end of any of them is it.
    @direction = params[:direction].presence_in(DIRECTIONS) if SislabSync.local?

    @referrals = scope.offset((page - 1) * PER_PAGE).limit(PER_PAGE).to_a
    @total = scope.count
    @page = page
    @pages = [ (@total / PER_PAGE.to_f).ceil, 1 ].max

    # Over what has actually arrived. A parcel still in transit has no transport
    # time yet, and counting it as zero would flatter the number.
    @average_transport = average_transport_time
    @outstanding = Referral.outstanding.count
  end

  private

  def scope
    relation = Referral.includes(:rejection_reason, order: :patient).order(dispatched_at: :desc, id: :desc)
    relation = relation.where(state: @state) if @state

    case @direction
    when "out" then relation.where(from_lab_code: SislabSync.lab_code)
    when "in" then relation.where(to_lab_code: SislabSync.lab_code)
    else relation
    end
  end

  def page
    [ params[:page].to_i, 1 ].max
  end

  # Over every referral ever received, not over the page being shown, and
  # computed in the database rather than by loading them all.
  def average_transport_time
    Referral.where.not(received_at: nil)
            .pick(Arel.sql("AVG(TIMESTAMPDIFF(SECOND, dispatched_at, received_at))"))
            &.to_f
  end
end
