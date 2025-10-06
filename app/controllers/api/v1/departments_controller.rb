# frozen_string_literal: true

module API
  module V1
    class DepartmentsController < ApplicationController
      skip_before_action :authenticate_request
      before_action :authenticate_frontend_ui_service, only: %i[create show edit update destroy]
      before_action :set_catalog
      before_action :set_department, only: %i[show update destroy]

      # GET /api/v1/test_catalogs/:catalog_id/departments
      def index
        departments = @catalog.catalog['departments'] || []
        departments = departments.map { |d| d&.with_indifferent_access }

        if params[:search].present?
          search_term = params[:search].downcase
          departments = departments.select do |d|
            [
              d[:name],
              d[:short_name],
              d[:preferred_name],
              d[:scientific_name],
              d[:moh_code],
              d[:nlims_code],
              d[:loinc_code],
              d[:description]
            ].compact.any? { |v| v.to_s.downcase.include?(search_term) }
          end
        end

        if params[:nlims_code].present?
          departments = departments.select do |d|
            d[:nlims_code].to_s.downcase.include?(params[:nlims_code].to_s.downcase)
          end
        end

        departments = departments.sort_by { |d| d[:name].to_s }
        render json: departments
      end

      # GET /api/v1/test_catalogs/:catalog_id/departments/:id
      def show
        render json: @department
      end

      # POST /api/v1/test_catalogs/:catalog_id/departments
      def create
        service = CatalogService.new(@catalog)
        department = service.create_department(department_params)

        render json: department, status: :created
      rescue StandardError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # PUT/PATCH /api/v1/test_catalogs/:catalog_id/departments/:id
      def update
        service = CatalogService.new(@catalog)
        department = service.update_department(@department['id'], department_params)

        render json: department
      rescue StandardError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # DELETE /api/v1/test_catalogs/:catalog_id/departments/:id
      def destroy
        service = CatalogService.new(@catalog)
        service.delete_department(@department['id'])

        head :no_content
      rescue StandardError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      def set_catalog
        @catalog = TestCatalogVersion.find_by(id: params[:catalog_id]) || TestCatalogVersion.last
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Catalog not found' }, status: :not_found
      end

      def set_department
        service = CatalogService.new(@catalog)
        @department = service.send(:find_department_in_catalog, params[:id])

        return if @department

        render json: { error: 'Department not found' }, status: :not_found
      end

      def department_params
        params.require(:department).permit(
          :name, :short_name, :preferred_name, :scientific_name,
          :description, :moh_code, :nlims_code, :loinc_code,
          :created_at, :updated_at
        )
      end
    end
  end
end
