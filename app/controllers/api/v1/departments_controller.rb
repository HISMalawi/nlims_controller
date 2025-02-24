# frozen_string_literal: true

# DepartmentsController module for API
module API
  # DepartmentsController module for V1
  module V1
    # DepartmentsController class for V1
    class DepartmentsController < ApplicationController
      before_action :set_department, only: %i[show edit update destroy]
      skip_before_action :authenticate_request, only: %i[index show]

      # GET /Departments
      def index
        @departments = if params[:search].present?
                         TestCategory.where('name LIKE ?', "%#{params[:search]}%")
                       else
                         TestCategory.all
                       end
        render json: @departments
      end

      # GET /Departments/:id
      def show
        render json: @department
      end

      # POST /Departments
      def create
        @department = TestCategory.new(department_params)
        if @department.save
          render json: @department, status: :created
        else
          render json: @department.errors, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /Departments/:id
      def update
        if @department.update(department_params)
          render json: @department
        else
          render json: @department.errors, status: :unprocessable_entity
        end
      end

      # DELETE /Departments/:id
      def destroy
        @drug.destroy
        head :no_content
      end

      private

      def set_set_department
        @department = TestCategory.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Department not found' }, status: :not_found
      end

      def department_params
        params.require(:department).permit(:name, :description, :short_name, :moh_code, :nlims_code, :loinc_code,
                                           :preferred_name, :scientific_name)
      end
    end
  end
end
