# frozen_string_literal: true

module API
  module V1
    class TestTypesController < ApplicationController
      skip_before_action :authenticate_request
      def index
        test_types = TestType.all
        render json: test_types
      end

      def show
        test_type = TestType.find(params[:id])
        render json: test_type.as_json(context: :single_item)
      end
    end
  end
end
