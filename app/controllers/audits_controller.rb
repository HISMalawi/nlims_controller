# frozen_string_literal: true

# Who called this node and what happened. One row per request, written whatever
# the outcome — the rejected ones being the ones worth having, since that is how
# a key being probed, or an integration pointed at the wrong node, becomes
# visible at all.
class AuditsController < ApplicationController
  before_action :require_admin

  PER_PAGE = 100

  def index
    @client = ApiClient.find_by(id: params[:api_client_id])
    @only_failures = params[:failures].present?

    @audits = scope.includes(:api_client, :api_key).offset((page - 1) * PER_PAGE).limit(PER_PAGE).to_a
    @total = scope.count
    @page = page
    @pages = [ (@total / PER_PAGE.to_f).ceil, 1 ].max

    @clients = ApiClient.order(:name)
    @failures_by_code = scope.where.not(error_code: nil).group(:error_code).count
  end

  private

  def scope
    relation = RequestAudit.order(created_at: :desc, id: :desc)
    relation = relation.where(api_client: @client) if @client
    relation = relation.where(status: 400..) if @only_failures
    relation
  end

  def page
    [ params[:page].to_i, 1 ].max
  end
end
