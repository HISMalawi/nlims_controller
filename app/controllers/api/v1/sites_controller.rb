# frozen_string_literal: true

# module API
module API
  # module V1
  module V1
    # SitesController
    class SitesController < ApplicationController
      before_action :set_site, only: %i[show update destroy]

      def index
        @sites = Site.all.order(:name)
        @sites = @sites.search(params[:q]) if params[:q].present?
        render json: @sites
      end

      def show
        render json: @site
      end

      def create
        @site = Site.create(site_params)
        render json: @site, status: :created
      end

      def update
        @site.update(site_params)
        render json: @site
      end

      private

      def set_site
        @site = Site.find(params[:id])
      end

      def site_params
        params.require(:site).permit(
          :name,
          :url,
          :district,
          :x,
          :y,
          :region,
          :description,
          :site_code,
          :application_port,
          :host_address,
          :couch_username,
          :couch_password,
          :site_code_number,
          :enabled
        )
      end
    end
  end
end
