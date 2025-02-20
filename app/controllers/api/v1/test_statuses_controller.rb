# frozen_string_literal: true

# Module API
module API
  # TestStatusesController module v1
  module V1
    # TestStatusesController class
    class TestStatusesController < ApplicationController
      before_action :set_test_status, only: %i[show edit update destroy]
      skip_before_action :authenticate_request, only: %i[index show]

      # GET /test_statuses
      def index
        @test_statuses = if params[:search].present?
                           TestStatus.where('name LIKE ?', "%#{params[:search]}%")
                         else
                           TestStatus.all
                         end
        render json: @test_statuses
      end

      # GET /test_statuses/:id
      def show
        render json: @test_status
      end

      # POST /test_statuses
      def create
        @test_status = TestStatus.new(test_status_params)
        if @test_status.save
          render json: @test_status, status: :created
        else
          render json: { errors: @test_status.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /test_statuses/:id
      def update
        if @test_status.update(test_status_params)
          render json: @test_status
        else
          render json: { errors: @test_status.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /test_statuses/:id
      def destroy
        @test_status.destroy
        head :no_content
      end

      private

      def set_test_status
        @test_status = TestStatus.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Test Status not found' }, status: :not_found
      end

      def test_status_params
        params.require(:test_status).permit(:name, :test_phase_id, :short_name, :moh_code, :nlims_code, :loinc_code,
                                            :preferred_name, :scientific_name, :description)
      end
    end
  end
end
