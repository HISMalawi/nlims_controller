# frozen_string_literal: true

require 'csig/csig_service'
# module Api

class API::V2::CsigController < ApplicationController
  def index
    per_page = params[:per_page] || 5
    page_number = params[:page_number] || 1
    distributed = params[:distributed]
    status = params[:status]
    q = params[:q]
    data = CsigService.list_of_sins(
      per_page: per_page,
      page_number: page_number,
      distributed: distributed,
      status: status,
      query: q
    )
    render json: data
  end

  def generate_specimen_tracking_id
    generated_ids = CsigService.generate_sin(params.require(:number_of_ids))
    render json: { data: generated_ids, message: 'Success' }, status: :created
  end

  def distribute_sin
    site = Site.find_by(name: params.require(:site_name))
    if site.nil?
      render json: {
        data: nil,
        message: "Site with name #{params.require(:site_name)} not found"
      }, status: :not_found
    else
      distributed_ids = CsigService.distribute_sin(params.require(:number_of_ids), site)
      render json: { data: distributed_ids, message: 'Success' }
    end
  end

  def check_if_sin_is_used
    sin_used = CsigService.sin_used?(params.require(:sin))
    render json: { data: sin_used }
  end

  def distributions(per_page: 25, page_number: 1, query: nil)
    per_page = params[:per_page] || 25
    page_number = params[:page_number] || 1
    query = params[:query]
    data = CsigService.distributions(
      per_page: per_page,
      page_number: page_number,
      query: query
    )
    render json: { data: data }
  end

  def distributions_by_facility
    facility_name = params[:facility_name]
    from = params[:from]
    to = params[:to]
    data = CsigService.distributions_by_facility(facility_name, from: from, to: to)
    render json: { data: data }
  end

  def use_sin
    sin = params.require(:sin)
    site_name = params.require(:site_name)
    system_name = params[:system_name]
    used_sin = CsigService.use_sin(sin, site_name, system_name)
    error = ['Invalid sin', true].include?(used_sin)
    message = error ? (used_sin == 'Invalid sin' ? 'Invalid sin' : 'Sin already used') : 'Success'
    data = error ? nil : used_sin
    render json: { data: data, error: error, message: message }
  end

  def not_distributed_ids_count
    count = SpecimenIdentification.where(distributed: false).count
    render json: { data: count }
  end

  def csig_status
    render json: CsigStatus.all
  end

  def analytics
    data = CsigService.analytics
    render json: { data: data }
  end
end
