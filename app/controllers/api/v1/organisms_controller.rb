# frozen_string_literal: true

module API
  module V1
    class OrganismsController < ApplicationController
      skip_before_action :authenticate_request
      before_action :authenticate_frontend_ui_service, only: %i[create show edit update destroy]
      before_action :set_catalog
      before_action :set_organism, only: %i[show update destroy]

      # GET /api/v1/test_catalogs/:catalog_id/organisms
      def index
        organisms = @catalog.catalog['organisms'] || []
        organisms = organisms.map { |o| o&.with_indifferent_access }

        if params[:search].present?
          search_term = params[:search].downcase
          organisms = organisms.select do |o|
            [
              o[:name],
              o[:short_name],
              o[:preferred_name],
              o[:scientific_name],
              o[:moh_code],
              o[:nlims_code],
              o[:loinc_code],
              o[:description]
            ].compact.any? { |v| v.to_s.downcase.include?(search_term) }
          end
        end

        if params[:nlims_code].present?
          organisms = organisms.select do |o|
            o[:nlims_code].to_s.downcase.include?(params[:nlims_code].to_s.downcase)
          end
        end

        organisms = organisms.sort_by { |o| o[:name].to_s }

        render json: organisms
      end

      # GET /api/v1/test_catalogs/:catalog_id/organisms/:id
      def show
        render json: @organism
      end

      # POST /api/v1/test_catalogs/:catalog_id/organisms
      def create
        service = CatalogService.new(@catalog)
        organism = service.create_organism(params)

        render json: organism, status: :created
      rescue StandardError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # PUT/PATCH /api/v1/test_catalogs/:catalog_id/organisms/:id
      def update
        service = CatalogService.new(@catalog)
        organism = service.update_organism(@organism['id'], params)

        render json: organism
      rescue StandardError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # DELETE /api/v1/test_catalogs/:catalog_id/organisms/:id
      def destroy
        service = CatalogService.new(@catalog)
        service.delete_organism(@organism['id'])

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

      def set_organism
        service = CatalogService.new(@catalog)
        @organism = service.send(:find_organism_in_catalog, params[:id])

        return if @organism

        render json: { error: 'Organism not found' }, status: :not_found
      end
    end
  end
end
