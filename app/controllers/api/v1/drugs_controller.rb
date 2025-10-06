# frozen_string_literal: true

module API
  module V1
    class DrugsController < ApplicationController
      skip_before_action :authenticate_request
      before_action :authenticate_frontend_ui_service, only: %i[create show edit update destroy]
      before_action :set_catalog
      before_action :set_drug, only: %i[show update destroy]

      # GET /api/v1/test_catalogs/:catalog_id/drugs
      def index
        drugs = @catalog.catalog['drugs'] || []
        drugs = drugs.map { |d| d&.with_indifferent_access }

        if params[:search].present?
          search_term = params[:search].downcase
          drugs = drugs.select do |d|
            [
              d[:name],
              d[:short_name],
              d[:preferred_name],
              d[:scientific_name],
              d[:nlims_code],
              d[:moh_code],
              d[:loinc_code]
            ].compact.any? { |v| v.to_s.downcase.include?(search_term) }
          end
        end

        if params[:nlims_code].present?
          drugs = drugs.select do |d|
            d[:nlims_code].to_s.downcase.include?(params[:nlims_code].to_s.downcase)
          end
        end

        drugs = drugs.sort_by { |d| d[:name].to_s }
        render json: drugs
      end

      # GET /api/v1/test_catalogs/:catalog_id/drugs/:id
      def show
        render json: @drug
      end

      # POST /api/v1/test_catalogs/:catalog_id/drugs
      def create
        service = CatalogService.new(@catalog)
        drug = service.create_drug(drug_params)

        render json: drug, status: :created
      rescue StandardError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # PUT/PATCH /api/v1/test_catalogs/:catalog_id/drugs/:id
      def update
        service = CatalogService.new(@catalog)
        drug = service.update_drug(@drug['id'], drug_params)

        render json: drug
      rescue StandardError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # DELETE /api/v1/test_catalogs/:catalog_id/drugs/:id
      def destroy
        service = CatalogService.new(@catalog)
        service.delete_drug(@drug['id'])

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

      def set_drug
        service = CatalogService.new(@catalog)
        @drug = service.send(:find_drug_in_catalog, params[:id])

        return if @drug

        render json: { error: 'Drug not found' }, status: :not_found
      end

      def drug_params
        params.require(:drug).permit(
          :name, :short_name, :preferred_name, :scientific_name,
          :description, :moh_code, :nlims_code, :loinc_code,
          :created_at, :updated_at
        )
      end
    end
  end
end
