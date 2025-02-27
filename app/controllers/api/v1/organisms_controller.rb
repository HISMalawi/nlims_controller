# OrganismsController module for API
module API
  # OrganismsController module for V1
  module V1
    # OrganismsController class for V1
    class OrganismsController < ApplicationController
      before_action :set_organism, only: %i[show edit update destroy]
      skip_before_action :authenticate_request, only: %i[index show]

      # GET /organisms
      def index
        @organisms = if params[:search].present?
                       Organism.where('name LIKE ?', "%#{params[:search]}%")
                     else
                       Organism.all
                     end
        render json: @organisms
      end

      # GET /organisms/:id
      def show
        render json: @organism
      end

      # POST /organisms
      def create
        @organism = Organism.new(organism_params.except(:drugs))
        if @organism.save
          update_organism_drugs
          render json: @organism, status: :created
        else
          render json: { errors: @organism.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /organisms/:id
      def update
        if @organism.update(organism_params.except(:drugs))
          update_organism_drugs
          render json: @organism
        else
          render json: { errors: @organism.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /organisms/:id
      def destroy
        @organism.destroy
        head :no_content
      end

      private

      def set_organism
        @organism = Organism.includes(:drugs).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Organism not found' }, status: :not_found
      end

      def organism_params
        params.require(:organism).permit(:name, :description, :short_name, :moh_code, :nlims_code, :loinc_code,
                                         :preferred_name, :scientific_name, drugs: [])
      end

      def update_organism_drugs
        return unless params[:drugs].present?

        @organism.drugs = Drug.where(id: params[:drugs])
      end
    end
  end
end
