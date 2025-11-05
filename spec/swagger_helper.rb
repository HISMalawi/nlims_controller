# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.openapi_root = Rails.root.join('swagger').to_s

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under openapi_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a openapi_spec tag to the
  # the root example_group in your specs, e.g. describe '...', openapi_spec: 'v2/swagger.json'
  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'NLIMS API',
        version: 'v1',
        description: 'API documentation for NLIMS'
      },
      paths: {},
      servers: [
        {
          url: 'http://{defaultHost}',
          variables: {
            defaultHost: {
              default: 'localhost:3009'
            }
          }
        }
      ],
      components: {
        securitySchemes: {
          tokenAuth: {
            type: :apiKey,
            in: :header,
            name: 'token',
            description: 'Authentication token. Example: token = your_api_key_here'
          }
        },
        schemas: {
          TestStatus: {
            type: :string,
            description: 'Available statuses for a test',
            enum: %w[
              not-received
              pending
              started
              completed
              verified
              voided
              not-done
              test-rejected
              drawn
              failed
              rejected
              test_on_repeat
              sample_accepted_at_hub
              sample_rejected_at_hub
              sample_intransit_to_ml
              sample_accepted_at_ml
              sample_rejected_at_ml
            ]
          },
          OrderStatus: {
            type: :string,
            description: 'Available statuses for a order',
            enum: %w[specimen_not_collected
                     specimen_accepted
                     specimen_rejected
                     specimen_collected
                     sample_accepted_at_hub
                     sample_rejected_at_hub
                     sample_accepted_at_ml
                     sample_rejected_at_ml]
          }
        }
      },
      security: [
        {
          tokenAuth: []
        }
      ]

    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The openapi_specs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.openapi_format = :yaml
end
