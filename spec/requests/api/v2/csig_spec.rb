# frozen_string_literal: true

require 'swagger_helper'

TAGS_CSIG = 'CSIG'
RSpec.describe 'api/v2/csig', type: :request do
  path '/api/v2/csig/generate_ids' do
    post('generate_specimen_tracking_id csig') do
      tags TAGS_CSIG
      consumes 'application/json'
      parameter in: :body, schema: {
        type: :object,
        properties: {
          number_of_ids: { type: :integer }
        },
        required: ['number_of_ids']
      }
      response(200, 'successful') do
        let(:number_of_ids) { 1 }
        run_test!
      end
    end
  end

  path '/api/v2/csig/distribute_ids' do
    post('distribute_sin csig') do
      response(200, 'successful') do
        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v2/csig/sin_used' do
    get('check_if_sin_is_used csig') do
      response(200, 'successful') do
        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v2/csig/use_sin' do
    post('use_sin csig') do
      response(200, 'successful') do
        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v2/csig' do
    get('list specimen tracking ids') do
      response(200, 'successful') do
        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end
end
