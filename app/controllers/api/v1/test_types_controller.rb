# frozen_string_literal: true

module API
  module V1
    class TestTypesController < ApplicationController
      skip_before_action :authenticate_request, only: %i[index show]
      before_action :set_test_type, only: %i[show update destroy]

      def index
        @test_types = if params[:search].present?
                        TestType.where('name LIKE ?', "%#{params[:search]}%")
                      else
                        TestType.all
                      end
        render json: @test_types.order(:name)
      end

      def show
        render json: @test_type.as_json(context: :single_item)
      end

      def create
        @test_type = TestCatalogService.create_test_type(test_type_params)
        render json: @test_type.as_json(context: :single_item), status: :created
      end

      def update
        TestCatalogService.update_test_type(@test_type, test_type_params)
        render json: @test_type.as_json(context: :single_item), status: :ok
      end

      def measures
        @measures = if params[:search].present?
                      Measure.where('name LIKE ?', "%#{params[:search]}%")
                    else
                      Measure.all
                    end
        render json: @measures
      end

      def measure_types
        @measure_types = if params[:search].present?
                           MeasureType.where('name LIKE ?', "%#{params[:search]}%")
                         else
                           MeasureType.all
                         end
        render json: @measure_types
      end

      def destroy
        @test_type.destroy
        render json: { message: 'Test type deleted successfully' }, status: :ok
      end

      private

      def test_type_params
        params.require(:test_catalog).permit(
          test_type: %i[
            name short_name description loinc_code moh_code nlims_code
            targetTAT preferred_name scientific_name can_be_done_on_sex test_category_id
            assay_format equipment_required hr_cadre_required iblis_mapping_name
          ],
          specimen_types: [],
          measures: [
            :id, :name, :short_name, :unit, :measure_type_id, :description, :loinc_code,
            :moh_code, :nlims_code, :preferred_name, :scientific_name, :iblis_mapping_name,
            { measure_ranges_attributes: %i[
              id age_min age_max range_lower range_upper sex value interpretation
            ] }
          ],
          organisms: [],
          lab_test_sites: []
        )
      end

      def set_test_type
        @test_type = TestType.find(params[:id])
      end
    end
  end
end
