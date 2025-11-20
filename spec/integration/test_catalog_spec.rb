# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Test Catalog API', type: :request do
  path '/api/v2/test_catalog/new_version/available' do
    get 'Check if a new test catalog version is available' do
      tags 'Test Catalog'
      produces 'application/json'
      security [tokenAuth: []]
      description 'Check if a new test catalog version is available based on the current version being used by the app'
      parameter name: :version, in: :query, type: :string, required: true,
                description: 'Current catalog version that is being used by the app currently, e.g., v1'

      response '200', 'Version information returned' do
        schema type: :object,
               properties: {
                 is_new_version_available: { type: :boolean, example: true },
                 version: { type: :string, example: 'v1' },
                 version_details: {
                   type: :object,
                   example: {
                     'releaseNotes' => [
                       {
                         'title' => 'Malawi Test Catalog Initial Version',
                         'changeType' => 'feature',
                         'description' => 'The Malawi Test Catalog (Initial Version) serves as the foundational reference for all laboratory tests conducted within the national health system. It defines standardized test names, methods, units of measurement, and result indicators to ensure consistency, quality, and interoperability across laboratories and electronic systems.'
                       }
                     ]
                   }
                 }
               }
        run_test!
      end
    end
  end
  path '/api/v2/test_catalog/{version}' do
    get 'Retrieve the full test catalog' do
      tags 'Test Catalog'
      produces 'application/json'
      security [tokenAuth: []]
      description 'Retrieve the full Malawi Test Catalog including departments, test types, test panels, measures, specimen types, lab test sites, and version details'

      parameter name: :version, in: :path, type: :string, required: true,
                description: 'Current catalog version to fetch, e.g., v1'

      response '200', 'Test catalog retrieved successfully' do
        schema type: :object

        run_test! do |response|
          # Parse the JSON and check that it is an object (catalog)
          data = JSON.parse(response.body)
          expect(data).to be_a(Hash)
          # Optionally, check for top-level keys if you want
          expect(data).to include('test_types', 'test_panels', 'departments', 'version_details')
        end
      end
    end
  end
end
