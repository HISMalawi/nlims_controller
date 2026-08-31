# frozen_string_literal: true

# Finding a sample and reading everything that happened to it.
#
# This is the screen the interface exists for. Someone telephones the laboratory
# with a tracking number, or a clinician asks where a result is, and the answer
# has to be one search away and complete when it arrives.
class OrdersController < ApplicationController
  def index
    @search = OrderSearch.new(search_params)

    # A whole tracking number is not a search, it is a destination.
    match = @search.exact_match
    redirect_to order_path(match.tracking_number) and return if match
  end

  def show
    @order = Order.includes(:patient, :specimen_type, :rejection_reason, order_tests: :test_type)
                  .find_by_tracking_number!(params[:tracking_number])

    # Everything under this tracking number, the order's transitions and its
    # tests', in the order they happened — one index scan, and the answer to
    # "what happened to this sample".
    @history = @order.status_events.to_a
    @results = TestResult.where(order_test: @order.order_tests)
                         .includes(:indicator, order_test: :test_type)
                         .order(:recorded_at, :id)
                         .to_a
    @referrals = @order.referrals.includes(:rejection_reason).order(:dispatched_at).to_a
  end

  private

  def search_params
    params.permit(:q, :status, :facility, :from, :to, :page)
  end
end
