# frozen_string_literal: true

# LabSite module for API
module API
  # LabSite module for V1
  module V1
    # LabSite class for V1
    class LabTestSitesController < ApplicationController
      skip_before_action :authenticate_request, only: %i[index show]

      # GET /Departments
      def index
        render json: LabTestSite.all
      end

      def show
        render json: LabTestSite.find(params[:id])
      end
    end
  end
end
