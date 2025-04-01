# frozen_string_literal: true

# DrugsController module for API
module API
  # DrugsController module for V1
  module V1
    # DrugsController class for V1
    class DrugsController < ApplicationController
      skip_before_action :authenticate_request
      before_action :authenticate_frontend_ui_service, only: %i[create show edit update destroy]
      before_action :set_drug, only: %i[show edit update destroy]

      # GET /drugs
      def index
        @drugs = if params[:search].present?
                   Drug.where('name LIKE ?', "%#{params[:search]}%")
                 else
                   Drug.all
                 end
        render json: @drugs
      end

      # GET /drugs/:id
      def show
        render json: @drug
      end

      # POST /drugs
      def create
        @drug = Drug.new(drug_params)
        if @drug.save
          render json: @drug, status: :created
        else
          render json: @drug.errors, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /drugs/:id
      def update
        if @drug.update(drug_params)
          render json: @drug
        else
          render json: @drug.errors, status: :unprocessable_entity
        end
      end

      # DELETE /drugs/:id
      def destroy
        @drug.destroy
        head :no_content
      end

      private

      def set_drug
        @drug = Drug.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Drug not found' }, status: :not_found
      end

      def drug_params
        params.require(:drug).permit(:name, :description, :short_name, :moh_code, :nlims_code, :loinc_code,
                                     :preferred_name, :scientific_name)
      end
    end
  end
end
