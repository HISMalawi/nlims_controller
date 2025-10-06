# frozen_string_literal: true

module API
  module V1
    class TestPanelsController < ApplicationController
      skip_before_action :authenticate_request
      before_action :authenticate_frontend_ui_service, only: %i[create show edit update destroy]
      before_action :set_catalog
      before_action :set_test_panel, only: %i[show update destroy]

      def index
        test_panels = @catalog.catalog['test_panels'] || []
        # Convert to hash with indifferent access for easier querying
        test_panels = test_panels.map { |tp| tp&.with_indifferent_access }

        if params[:search].present?
          search_term = params[:search].downcase
          test_panels = test_panels.select do |tp|
            [
              tp[:name],
              tp[:preferred_name],
              tp[:scientific_name],
              tp[:nlims_code],
              tp[:moh_code],
              tp[:loinc_code],
              tp[:short_name]
            ].compact.any? { |v| v.to_s.downcase.include?(search_term) }
          end
        end

        if params[:nlims_code].present?
          test_panels = test_panels.select do |tp|
            tp[:nlims_code].to_s.downcase.include?(params[:nlims_code].to_s.downcase)
          end
        end
        test_panels = test_panels.sort_by { |tp| tp[:name].to_s }
        render json: test_panels
      end

      def show
        render json: @test_panel
      end

      def create
        service = CatalogService.new(@catalog)
        test_panel = service.create_test_panel(test_panel_params)

        render json: test_panel, status: :created
      rescue StandardError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      def update
        service = CatalogService.new(@catalog)
        test_panel = service.update_test_panel(@test_panel['id'], test_panel_params)

        render json: test_panel
      rescue StandardError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      def destroy
        service = CatalogService.new(@catalog)
        service.delete_test_panel(@test_panel['id'])

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

      def set_test_panel
        service = CatalogService.new(@catalog)
        @test_panel = service.send(:find_test_panel_in_catalog, params[:id])

        return if @test_panel

        render json: { error: 'Test panel not found' }, status: :not_found
      end

      def test_panel_params
        params.require(:test_panel).permit(
          :name, :moh_code, :nlims_code, :loinc_code,
          :preferred_name, :scientific_name, :description,
          :short_name, :created_at, :updated_at,
          test_types: []
        )
      end
    end
  end
end
