# frozen_string_literal: true

module API
  module V1
    class SpecimenTypesController < ApplicationController
      skip_before_action :authenticate_request
      before_action :set_specimen_type, only: %i[show update destroy]

      def index
        @specimen_types = if params[:search].present?
                            SpecimenType.where('name LIKE ?', "%#{params[:search]}%")
                          else
                            SpecimenType.all
                          end
        render json: @specimen_types
      end

      def show
        render json: @specimen_type.as_json(context: :single_item)
      end

      def create
        @specimen_type = SpecimenType.create!(specimen_type_params)
        render json: @specimen_type.as_json(context: :single_item), status: :created
      end

      def update
        @specimen_type.update!(specimen_type_params)
        render json: @specimen_type.as_json(context: :single_item), status: :ok
      end

      def destroy
        @specimen_type.destroy
        render json: { message: 'Specimen type deleted successfully' }, status: :ok
      end

      private

      def specimen_type_params
        params.require(:specimen_type).permit(:name, :moh_code, :nlims_code, :loinc_code,
                                              :preferred_name, :scientific_name, :description)
      end

      def set_specimen_type
        @specimen_type = SpecimenType.find(params[:id])
      end
    end
  end
end
