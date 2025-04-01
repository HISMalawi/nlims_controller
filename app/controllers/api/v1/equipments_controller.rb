# frozen_string_literal: true

# Module API
module API
  # module for V1
  module V1
    # EquipmentsController
    class EquipmentsController < ApplicationController
      before_action :authenticate_frontend_ui_service, only: %i[create show edit update destroy]
      before_action :set_equipment, only: %i[show update destroy]
      skip_before_action :authenticate_request

      # GET /equipment
      def index
        @equipment = if params[:search].present?
                       Equipment.where('name LIKE ?', "%#{params[:search]}%")
                     else
                       Equipment.all
                     end

        render json: @equipment
      end

      # GET /equipment/1
      def show
        render json: @equipment
      end

      # POST /equipment
      def create
        @equipment = Equipment.new(equipment_params.except(:products))
        if @equipment.save
          update_equipment_products
          render json: @equipment, status: :created
        else
          render json: @equipment.errors, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /equipment/1
      def update
        if @equipment.update(equipment_params.except(:products))
          update_equipment_products
          render json: @equipment
        else
          render json: @equipment.errors, status: :unprocessable_entity
        end
      end

      # DELETE /equipment/1
      def destroy
        @equipment.destroy!
      end

      private

        # Use callbacks to share common setup or constraints between actions.
        def set_equipment
          @equipment = Equipment.includes(:products).find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: 'Equipment not found' }, status: :not_found
        end

        def update_equipment_products
          return unless params[:equipment][:products].present?

          @equipment.products = Product.where(id: params[:equipment][:products])
        end

        # Only allow a list of trusted parameters through.
        def equipment_params
          params.require(:equipment).permit(:name, :description, :nlims_code, :moh_code, :loinc_code, products: [])
        end
    end
  end
end
