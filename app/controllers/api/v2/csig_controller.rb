# frozen_string_literal: true

require 'csig/csig_service'
# module Api
module API
  # module V2
  module V2
    # class CsigController
    class CsigController < ApplicationController
      def generate_specimen_tracking_id
        generated_ids = CsigService.generate_sin(params.require(:number_of_ids))
        render json: { data: generated_ids, message: 'Success' }, status: :created
      end

      def distribute_sin
        site = Site.find_by(name: params.require(:site_name))
        if site.nil?
          render json: { data: nil, message: "Site with name #{params.require(:site_name)} not found" }
        else
          distributed_ids = CsigService.distribute_sin(params.require(:number_of_ids), site)
          render json: { data: distributed_ids, message: 'Success' }, status: :ok
        end
      end

      def check_if_sin_is_used
        sin_used = CsigService.sin_used?(params.require(:sin))
        render json: { data: sin_used }, status: :ok
      end

      def use_sin
        sin = params.require(:sin)
        site_name = params.require(:site_name)
        system_name = params[:system_name]
        used_sin = CsigService.use_sin(sin, site_name, system_name)
        if used_sin == true
          render json: { data: nil, message: 'Sin already used' }, status: :created
        else
          render json: { data: used_sin, message: 'Success' }, status: :created
        end
      end
    end
  end
end
