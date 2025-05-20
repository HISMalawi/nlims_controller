# TestPanels module for API
module API
  # TestPanels module for V1
  module V1
    # TestPanels class for V1
    class TestPanelsController < ApplicationController
      skip_before_action :authenticate_request
      before_action :authenticate_frontend_ui_service, only: %i[create show edit update destroy]
      before_action :set_test_panel, only: %i[show edit update destroy]

      # GET /test_panels
      def index
        @test_panels = if params[:search].present?
                         PanelType.where('name LIKE ?', "%#{params[:search]}%")
                       else
                         PanelType.all
                       end
        render json: @test_panels.order(:name)
      end

      # GET /test_panels/:id
      def show
        render json: @test_panel
      end

      # POST /test_panels
      def create
        @test_panel = PanelType.new(test_panel_params.except(:test_types))
        if @test_panel.save
          update_test_panel_test_type
          render json: @test_panel, status: :created
        else
          render json: { errors: @test_panel.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /test_panels/:id
      def update
        if @test_panel.update(test_panel_params.except(:test_types))
          update_test_panel_test_type
          render json: @test_panel
        else
          render json: { errors: @test_panel.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /test_panels/:id
      def destroy
        @test_panel.destroy
        head :no_content
      end

      private

      def set_test_panel
        @test_panel = PanelType.includes(:test_types).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Test Panel not found' }, status: :not_found
      end

      def test_panel_params
        params.require(:test_panel).permit(:name, :description, :short_name, :moh_code, :nlims_code, :loinc_code,
                                           :preferred_name, :scientific_name, test_types: [])
      end

      def update_test_panel_test_type
        test_types = params[:test_panel][:test_types]
        return unless test_types.present?

        @test_panel.test_types = TestType.where(id: test_types)
      end
    end
  end
end
