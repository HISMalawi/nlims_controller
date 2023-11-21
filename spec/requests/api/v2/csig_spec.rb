# frozen_string_literal: true

require 'swagger_helper'

TAGS_CSIG = 'CSIG'
RSpec.describe 'api/v2/csig', type: :request do
  path '/api/v2/csig/generate_ids' do
    post('generate specimen tracking ids') do
      tags TAGS_CSIG
      consumes 'application/json'
      produces 'application/json'
      parameter in: :body, schema: {
        type: :object,
        properties: {
          number_of_ids: { type: :integer, example: 10, default: 100 }
        },
        required: ['number_of_ids']
      }
      response(200, 'successful') do
        schema type: :array,
               items: {
                 type: :object,
                 properties: {
                   id: { type: :integer, example: 221200 },
                   sequence_number: { type: :string, example: '221200' },
                   base9_equivalent: { type: :string, example: '366377' },
                   base9_zero_padded: { type: :string, example: '0000366377' },
                   encrypted: { type: :string, example: '2155087835' },
                   encrypted_zero_cleaned: { type: :string, example: '3266198946' },
                   check_digit: { type: :string, example: '74' },
                   sin: { type: :string, example: '743266198946' },
                   created_at: { type: :string, format: 'date-time', example: '2023-10-17T14:57:18.000+02:00' },
                   updated_at: { type: :string, format: 'date-time', example: '2023-10-17T14:57:18.000+02:00' },
                   distributed: { type: :boolean, example: false }
                 }
               }
        run_test!
      end
    end
  end

  path '/api/v2/csig/distribute_ids' do
    post('distribute specimen tracking ids') do
      tags TAGS_CSIG
      consumes 'application/json'
      parameter in: :body, schema: {
        type: :object,
        properties: {
          sites: { type: :array, items: { type: :integer } },
          number_of_ids: { type: :integer }
        },
        required: %w[sites number_of_ids]
      }
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
    get('check if specimen tracking id is used') do
      tags TAGS_CSIG
      parameter name: :sin, in: :query, type: :string, required: true
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
      tags TAGS_CSIG
      consumes 'application/json'
      parameter in: :body, schema: {
        type: :object,
        properties: {
          sin: { type: :string },
          site_name: { type: :string },
          system_name: { type: :string }
        },
        required: %w[sin site_name]
      }
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
    get('list csig specimen tracking ids') do
      tags TAGS_CSIG
      parameter name: :per_page, in: :query, type: :integer, required: false
      parameter name: :page_number, in: :query, type: :integer, required: false
      parameter name: :distributed, in: :query, type: :boolean, required: false
      parameter name: :status, in: :query, type: :integer, required: false
      parameter name: :q, in: :query, type: :string, required: false
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
  path '/api/v2/csig/status' do
    get('list csig statuses') do
      tags TAGS_CSIG
      produces 'application/json'
      response(200, 'successful') do
        schema type: :array,
        items: {
          type: :object,
            properties: {
              id: { type: :integer, example: 1 },
              name: { type: :string, example: 'Not Distributed' },
              description: { type: :string, example: 'Not Distributed' },
              created_at: { type: :string, format: 'date-time', example: '2023-10-17T14:57:18.000+02:00' },
            }
        }
        run_test!
      end
    end
  end
  path '/api/v2/csig/not_distributed_ids_count' do
    get('Get total count of ids not distributed') do
      tags TAGS_CSIG
      produces 'application/json'
      response(200, 'successful') do
        schema type: :object,
            properties: {
              data: { type: :integer, example: 1 }
            }
        run_test!
      end
    end
  end
end
