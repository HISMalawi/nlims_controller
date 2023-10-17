# frozen_string_literal: true

require 'swagger_helper'

TAGS_CSIG = 'Users'
RSpec.describe 'api/v1/users', type: :request do
  path '/api/v1/re_authenticate/{username}/{password}' do
    get('Login') do
      tags TAGS_CSIG
      parameter name: :username, in: :path, type: :string, required: true
      parameter name: :password, in: :path, type: :string, required: true
      produces 'application/json'
      response(200, 'successful') do
        schema type: :object,
               properties: {
                 status: { type: :integer, example: 200 },
                 error: { type: :boolean, example: false },
                 message: { type: :string, example: 're authentication successfuly' },
                 data: {
                   type: :object,
                   properties: {
                     token: { type: :string, example: 'pgq13sZpUFT6' },
                     expiry_time: { type: :string, example: '20231017180719' }
                   }
                 }
               }
        run_test!
      end
      response(401, 'unauthorized') do
        schema type: :object,
               properties: {
                 status: { type: :integer, example: 401 },
                 error: { type: :boolean, example: true },
                 message: { type: :string, example: 'wrong username or password' },
                 data: { type: :object, example: {} }
               }
        run_test!
      end
    end
  end
end
