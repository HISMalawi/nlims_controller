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
        let(:username) { username }
        let(:password) { password }
        run_test!
      end
    end
  end
end
