# frozen_string_literal: true

# Module API
module API
  # module for V2
  module V2
    # Test Catalog Version manager
    class TestCatalogVersionManagersController < ApplicationController
      def show
        version = TestCatalogManagement::TestCatalogVersionManager.retrieve_test_catalog(params[:version])
        render json: version&.as_json(except: %i[status approved_by rejected_by approved_at rejected_at
                                                 rejection_reason])
      end

      def new_version_available
        render json: TestCatalogManagement::TestCatalogVersionManager.new_version_available?(params[:version])
      end
    end
  end
end
