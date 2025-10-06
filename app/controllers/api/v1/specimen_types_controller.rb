# frozen_string_literal: true

module API
  module V1
    class SpecimenTypesController < ApplicationController
      skip_before_action :authenticate_request
      before_action :authenticate_frontend_ui_service, only: %i[create show edit update destroy]
      before_action :set_catalog
      before_action :set_specimen_type, only: %i[show update destroy]

      def index
        specimen_types = @catalog.catalog['specimen_types'] || []
        # Convert to hash with indifferent access for easier querying
        specimen_types = specimen_types.map { |st| st&.with_indifferent_access }

        if params[:search].present?
          search_term = params[:search].downcase
          specimen_types = specimen_types.select do |st|
            [
              st[:name],
              st[:preferred_name],
              st[:scientific_name],
              st[:nlims_code],
              st[:moh_code],
              st[:loinc_code],
              st[:iblis_mapping_name]
            ].compact.any? { |v| v.to_s.downcase.include?(search_term) }
          end
        end

        if params[:nlims_code].present?
          specimen_types = specimen_types.select do |st|
            st[:nlims_code].to_s.downcase.include?(params[:nlims_code].to_s.downcase)
          end
        end
        specimen_types = specimen_types.sort_by { |st| st[:name].to_s }
        render json: specimen_types
      end

      def show
        render json: @specimen_type
      end

      def create
        service = CatalogService.new(@catalog)
        specimen_type = service.create_specimen_type(specimen_type_params)

        render json: specimen_type, status: :created
      rescue StandardError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      def update
        service = CatalogService.new(@catalog)
        specimen_type = service.update_specimen_type(@specimen_type['id'], specimen_type_params)

        render json: specimen_type
      rescue StandardError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      def destroy
        service = CatalogService.new(@catalog)
        service.delete_specimen_type(@specimen_type['id'])

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

      def set_specimen_type
        service = CatalogService.new(@catalog)
        @specimen_type = service.send(:find_specimen_type_in_catalog, params[:id])

        return if @specimen_type

        render json: { error: 'Specimen type not found' }, status: :not_found
      end

      def specimen_type_params
        params.permit(
          :catalog_id,
          specimen_type: [
            :name, :moh_code, :nlims_code, :loinc_code,
            :preferred_name, :scientific_name, :description, 
            :iblis_mapping_name, :created_at, :updated_at
          ]
        )
      end
    end
  end
end