# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Authentication API', type: :request do
  path '/api/v1/login' do
    post 'Authenticate a user and return a token' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      description 'Authenticate a user and return a token'
      parameter name: :credentials, in: :body, schema: {
        type: :object,
        required: %w[username password],
        properties: {
          username: { type: :string, example: 'admin' },
          password: { type: :string, example: 'password123' }
        }
      }

      response '200', 'login successful' do
        schema type: :object,
               properties: {
                 user: {
                   type: :object,
                   properties: {
                     id: { type: :integer, example: 1 },
                     username: { type: :string, example: 'admin' },
                     app_name: { type: :string, example: 'nlims' },
                     app_uuid: { type: :string, example: '99d18d28-7360-4356-b378-8ca438012be9' },
                     disabled: { type: :boolean, example: false },
                     location: { type: :string, example: 'lilongwe' },
                     partner: { type: :string, example: 'api_admin' },
                     roles: {
                       type: :array,
                       items: {
                         type: :object,
                         properties: {
                           name: { type: :string, example: 'admin' }
                         }
                       }
                     }
                   }
                 },
                 data: {
                   type: :object,
                   properties: {
                     token: { type: :string, example: '193625fa-534c-4470-a557-9c60f41799a9' },
                     expiry_time: { type: :string, example: '20251105142432' }
                   }
                 }
               }

        run_test!
      end

      response '401', 'invalid credentials' do
        schema type: :object,
               properties: {
                 message: { type: :string, example: 'Wrong username or password' }
               }

        run_test!
      end
    end
  end
end
