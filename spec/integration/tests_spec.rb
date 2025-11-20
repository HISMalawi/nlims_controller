# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Tests API', type: :request do
  path '/api/v2/tests/{tracking_number}' do
    put 'Update a laboratory test' do
      tags 'Tests'
      consumes 'application/json'
      produces 'application/json'
      security [tokenAuth: []]
      description 'Update a laboratory test'
      parameter name: :tracking_number, in: :path, type: :string, required: true
      parameter name: :test_payload, in: :body, schema: {
        type: :object,
        required: %w[test_status test_type],
        properties: {
          arv_number: { type: :string },
          uuid: { type: :string, description: 'Unique test identifier' },
          test_status: { type: :string, description: 'New status of the test' },
          time_updated: { type: :string, format: 'date-time', description: 'Time of update' },

          test_type: {
            type: :object,
            required: %w[name nlims_code],
            properties: {
              name: { type: :string },
              nlims_code: { type: :string }
            }
          },

          status_trail: {
            type: :array,
            items: {
              type: :object,
              required: %w[status timestamp],
              properties: {
                status_id: { type: :integer },
                status: { type: :string },
                timestamp: { type: :string, format: 'date-time' },
                updated_by: {
                  type: :object,
                  properties: {
                    first_name: { type: :string },
                    last_name: { type: :string },
                    id: { type: :string },
                    phone_number: { type: :string }
                  }
                }
              }
            }
          },

          test_results: {
            type: :array,
            items: {
              type: :object,
              properties: {
                measure: {
                  type: :object,
                  required: %w[name nlims_code],
                  properties: {
                    name: { type: :string },
                    nlims_code: { type: :string }
                  }
                },
                result: {
                  type: :object,
                  required: %w[value result_date],
                  properties: {
                    value: { type: :string },
                    unit: { type: :string },
                    result_date: { type: :string, format: 'date-time' },
                    platform: { type: :string },
                    platformserial: { type: :string }
                  }
                }
              }
            }
          }
        },
        example: {
          arv_number: 'N/A',
          uuid: 'af28a817-0ae6-49ed-9cae-a93c33a5eb3a',
          test_status: 'voided',
          time_updated: '2025-02-24T15:19:56.000+02:00',
          test_type: { name: 'Full Blood Count', nlims_code: 'NLIMS_TT_0035_MWI' },
          status_trail: [
            {
              status_id: 2,
              status: 'pending',
              timestamp: '2025-02-24T14:29:00.000+02:00',
              updated_by: { first_name: 'OCTAVIA', last_name: 'KALULU', id: '138', phone_number: '' }
            },
            {
              status_id: 3,
              status: 'started',
              timestamp: '2025-02-24T14:31:42.000+02:00',
              updated_by: { first_name: 'chacho', last_name: 'namaheya', id: '121', phone_number: '' }
            },
            {
              status_id: 6,
              status: 'voided',
              timestamp: '2025-02-24T15:19:56.000+02:00',
              updated_by: { first_name: 'chacho', last_name: 'namaheya', id: '121', phone_number: '' }
            }
          ],
          "test_results": [
            {
              "measure": {
                "name": 'Viral Load',
                "nlims_code": 'NLIMS_TI_0294_MWI'
              },
              "result": {
                "value": '100w00',
                "unit": 'copies/mL',
                "result_date": '2025-09-13 04:10:02',
                "platform": 'Abbot',
                "platformserial": '275021258'
              }
            }
          ]
        }
      }

      response '200', 'test successfully updated' do
        schema type: :object,
               properties: {
                 message: { type: :string, example: 'test successfully updated' },
                 data: { type: :object }
               }
        run_test!
      end

      response '422', 'Error: Unprocessable Entity' do
        schema type: :object,
               properties: {
                 error: { type: :boolean, example: true },
                 message: { type: :string, example: 'order with such test not available' },
                 data: { type: :object, example: {} }
               }
        run_test!
      end
    end
  end

  path '/api/v2/tests/{tracking_number}/acknowledge_test_results_receipt' do
    post 'Acknowledge test results receipt' do
      tags 'Tests'
      consumes 'application/json'
      produces 'application/json'
      security [tokenAuth: []]
      description 'Acknowledge test results receipt'
      parameter name: :tracking_number, in: :path, type: :string, required: true
      parameter name: :acknowledgement_payload, in: :body, schema: {
        type: :object,
        required: %w[test_type date_acknowledged recipient_type],
        properties: {
          test_type: {
            type: :object,
            required: %w[name nlims_code],
            properties: {
              name: { type: :string },
              nlims_code: { type: :string }
            }
          },
          date_acknowledged: { type: :string, format: 'date-time' },
          recipient_type: { type: :string },
          acknowledged_by: { type: :string }
        },
        example: {
          test_type: { name: 'HIV Viral Load', nlims_code: 'NLIMS_TI_0294_MWI' },
          date_acknowledged: '2025-02-24T15:19:56.000+02:00',
          recipient_type: 'test_results_delivered_to_site_electronically',
          acknowledged_by: 'emr_at_facility'
        }
      }

      response '200', 'test results receipt acknowledged successfully' do
        schema type: :object,
               properties: {
                 message: { type: :string, example: 'test results receipt acknowledged successfully' },
                 data: { type: :object }
               }
        run_test!
      end

      response '422', 'Error: Unprocessable Entity' do
        schema type: :object,
               properties: {
                 error: { type: :boolean, example: true },
                 message: { type: :string, example: 'test results receipt already acknowledged' },
                 data: { type: :object, example: {} }
               }
        run_test!
      end
    end
  end
end
