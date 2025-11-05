# frozen_string_literal: true

# Module API
module API
  # module for V1
  module V1
    # ProductsController
    class ProductsController < ApplicationController
      before_action :set_product, only: %i[show update destroy]
      skip_before_action :authenticate_request
      before_action :authenticate_frontend_ui_service, only: %i[create show edit update destroy]
      # GET /products
      def index
        @products = if params[:search].present?
                      Product.where('name LIKE ?', "%#{params[:search]}%")
                    else
                      Product.all
                    end

        render json: @products.order(:name)
      end

      # GET /products/1
      def show
        render json: @product
      end

      # POST /products
      def create
        @product = Product.new(product_params)

        if @product.save
          render json: @product, status: :created
        else
          render json: @product.errors, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /products/1
      def update
        if @product.update(product_params)
          render json: @product
        else
          render json: @product.errors, status: :unprocessable_entity
        end
      end

      # DELETE /products/1
      def destroy
        @product.destroy!
      end

      private

        # Use callbacks to share common setup or constraints between actions.
        def set_product
          @product = Product.find(params[:id])
        end

        # Only allow a list of trusted parameters through.
        def product_params
          params.require(:product).permit(:name, :description, :nlims_code, :moh_code, :loinc_code)
        end
    end
  end
end
