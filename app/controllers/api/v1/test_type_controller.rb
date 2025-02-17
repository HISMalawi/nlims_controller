# frozen_string_literal: true

module API
  module V1
    class TestTypeController < ApplicationController
      skip_before_action :authenticate_request
      def index
        test_types = TestType.all
        render json: test_types
      end

      def create_order; end
    end
  end
end
