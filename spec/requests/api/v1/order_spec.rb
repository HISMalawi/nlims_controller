# frozen_string_literal: true

require 'swagger_helper'

TAG = 'Order'

RSpec.describe 'api/v1/order', type: :request do
  path '/api/v1/create_order' do
    post('create_order order') do
      tags TAG
      consumes 'application/json'
      produces 'application/json'
      parameter in: :body, schema: {
        type: :object,
          properties: {
            district: { type: :string, example: 'Mzimba', description:  'District where the order is coming from'},
            health_facility_name: { type: :string, example: 'Mzimba South Health Centre', description: 'Name of the health facility where the order is coming from'},
            requesting_clinician: { type: :string, example: 'Dr. John Doe', description: 'Name of the clinician requesting the order'},
            first_name: { type: :string, example: 'John', description: 'First name of the patient'},
            last_name: { type: :string, example: 'Doe', description: 'Last name of the patient'},
            phone_number: { type: :string, example: '0888888888', description: 'Phone number of the patient'},
            gender: { type: :string, example: 'F', description: 'Gender of the patient', enum: ['M', 'F']},
            national_patient_id: { type: :string, example: '123456789', description: 'National patient Identifier of the patient'},
            sample_type: { type: :string, example: 'Blood', description: 'Sample type'},
            tests: { type: :array, items: { type: :string, example: 'FBC'}, description: 'Tests to be performed on the sample'},
            date_sample_drawn: { type: :string, example: '2023-10-17T14:57:18.000+02:00', description: 'Date sample was drawn'},
            sample_status: { type: :string, example: 'specimen_not_collected', description: 'Sample status', enum: ['specimen_not_collected', 'specimen_accepted', 'specimen_rejected', 'specimen_collected']},
            sample_priority: { type: :string, example: 'routine', description: 'Reason for testing'},
            target_lab: { type: :string, example: 'Lighthouse', description: 'Target lab is the lab where the sample is going to be tested'},
            order_location: { type: :string, example: 'Mzimba South Health Centre', description: 'Order location is the health facility or ward where the sample has been collected from'},
            who_order_test_first_name: { type: :string, example: 'John', description: 'First name of the person who drew the test'},
            who_order_test_last_name: { type: :string, example: 'Doe', description: 'Last name of the person who drew the test'},
            tracking_number: { type: :string, example: 'xkch123s2', description: 'Tracking number aka the national accession number of the order'}
          },
          required: %w[
            district
            health_facility_name
            requesting_clinician
            first_name
            last_name
            gender
            sample_type
            tests
            date_sample_drawn
            sample_priority
            target_lab
            order_location
            sample_status
          ]
        }
      response(200, 'Order creation successful') do
        schema type: :object,
         properties: {
          status: { type: :integer, example: 200 },
          error: { type: :boolean, example: false},
          message: { type: :string, example: 'order created successfully' },
          data: {
            type: :object,
            properties: {
              tracking_number: { type: :string, example: 'xkch123s2', description: 'Tracking number tied to the order'},
              couch_id: { type: :string, example: 'cdrjtgwit4065680285843', description: 'CouchDB id tied to the order'},
            }
          }
         }
        run_test!
      end
      response(409, 'Order with such tracking number already exists') do
        schema type: :object,
         properties: {
          status: { type: :integer, example: 200 },
          error: { type: :boolean, example: false},
          message: { type: :string, example: 'order already available' },
          data: {
            type: :object,
            properties: {
              tracking_number: { type: :string, example: 'xkch123s2', description: 'Tracking number tied to the order'},
            }
          }
         }
        run_test!
      end
      response(401, 'Error') do
        schema type: :object,
         properties: {
          status: { type: :integer, example: 401 },
          error: { type: :boolean, example: true },
          message: { type: :string },
          data: {
            type: :object
          }
         }
        run_test!
      end
    end
  end

  path '/api/v1/query_results_by_tracking_number/{tracking_number}' do
    parameter name: 'tracking_number', in: :path, type: :string, description: 'Tracking number of the order in question'
    get('Query order results by tracking number') do
      tags TAG
      produces 'application/json'
      response(200, 'results retrieved successfuly') do
        schema type: :object,
          properties: {
            status: { type: :integer, example: 200 },
            error: { type: :boolean, example: false },
            message: { type: :string, example: 'results retrieved successfuly' },
            data: {
              type: :object,
              properties: {
                tracking_number: { type: :string, example: 'xhce232s23', description: 'Tracking number tied to the order' },
                results: {
                  type: :object,
                  properties: {
                    FBC: {
                      type: :object,
                      properties: {
                        RBC: { type: :string, example: '4.13' },
                        HGB: { type: :string, example: '12.5' },
                        HCT: { type: :string, example: '37.6' },
                        MCV: { type: :string, example: '91.0' },
                        MCH: { type: :string, example: '30.3' },
                        MCHC: { type: :string, example: '33.2' },
                        PLT: { type: :string, example: '97.0' },
                        PDW: { type: :string, example: '13.0' },
                        MPV: { type: :string, example: '10.9' },
                        PCT: { type: :string, example: '0.11' },
                        "MONO\#" => { type: :string, example: '0.23' },
                        "P-LCC" =>  { type: :string, example: '0.23' },
                        result_date: { type: :string, example: '2016-05-23' }
                      }
                    },
                    'Viral Load' => {
                      type: :object,
                      properties: {
                        'Viral Load' => { type: :string, example: '< LDL' },
                        result_date: { type: :string, example: '2016-05-23' }
                      }
                    }
                  }
                }
              }
            }
          }
        run_test!
      end
      
      response(401, 'Error or results not available') do
        schema type: :object,
         properties: {
          status: { type: :integer, example: 401 },
          error: { type: :boolean, example: true },
          message: { type: :string },
          data: {
            type: :object
          }
         }
        run_test!
      end
    end
  end

  path '/api/v1/query_order_by_tracking_number/{tracking_number}' do
    # You'll want to customize the parameter types...
    parameter name: 'tracking_number', in: :path, type: :string, description: 'tracking_number'

    get('query_order_by_tracking_number order') do
      response(200, 'successful') do
        let(:tracking_number) { '123' }

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

  path '/api/v1/query_order_by_npid/{npid}' do
    # You'll want to customize the parameter types...
    parameter name: 'npid', in: :path, type: :string, description: 'npid'

    get('query_order_by_npid order') do
      response(200, 'successful') do
        let(:npid) { '123' }

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

  path '/api/v1/query_results_by_npid/{npid}' do
    # You'll want to customize the parameter types...
    parameter name: 'npid', in: :path, type: :string, description: 'npid'

    get('query_results_by_npid order') do
      response(200, 'successful') do
        let(:npid) { '123' }

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

  path '/api/v1/update_order' do

    post('update_order order') do
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

  path '/api/v1/query_requested_order_by_npid/{npid}' do
    # You'll want to customize the parameter types...
    parameter name: 'npid', in: :path, type: :string, description: 'npid'

    get('query_requested_order_by_npid order') do
      response(200, 'successful') do
        let(:npid) { '123' }

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

  path '/api/v1/dispatch_sample' do

    post('dispatch_sample order') do
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

  path '/api/v1/check_if_dispatched/{tracking_number}' do
    # You'll want to customize the parameter types...
    parameter name: 'tracking_number', in: :path, type: :string, description: 'tracking_number'

    get('check_if_dispatched order') do
      response(200, 'successful') do
        let(:tracking_number) { '123' }

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

  path '/api/v1/retrieve_undispatched_samples' do

    get('retrieve_undispatched_samples order') do
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

  path '/api/v1/retrieve_samples/{order_date}/{region}' do
    # You'll want to customize the parameter types...
    parameter name: 'order_date', in: :path, type: :string, description: 'order_date'
    parameter name: 'region', in: :path, type: :string, description: 'region'

    get('retrieve_samples order') do
      response(200, 'successful') do
        let(:order_date) { '123' }
        let(:region) { '123' }

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
