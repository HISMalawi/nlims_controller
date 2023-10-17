require 'swagger_helper'

TAG = 'Sites'
RSpec.describe 'api/v1/sites', type: :request do
  path '/api/v1/sites' do
    get('list sites') do
      tags TAG
      produces 'application/json'
      parameter name: :q, in: :query, type: :string, description: 'Search name of site query'
      response(200, 'successful') do
        schema type: :array,
               items: {
                 type: :object,
                 properties: {
                   id: { type: :integer, example: 2331 },
                   name: { type: :string, example: 'Kamuzu Academy Clinic' },
                   district: { type: :string, example: 'kasungu' },
                   x: { type: :number, format: :float, example: 33.6884 },
                   y: { type: :number, format: :float, example: -13.0294 },
                   region: { type: :string, example: 'Central' },
                   description: { type: :string, example: 'Clinic' },
                   enabled: { type: :boolean, example: false },
                   sync_status: { type: :boolean, example: false },
                   site_code: { type: :string, example: '' },
                   application_port: { type: :string, example: '0000' },
                   host_address: { type: :string, example: '' },
                   couch_username: { type: :string, example: '' },
                   couch_password: { type: :string, example: '' },
                   created_at: { type: :string, format: 'date-time', example: '2021-07-29T11:24:55.000+02:00' },
                   updated_at: { type: :string, format: 'date-time', example: '2021-07-29T11:24:55.000+02:00' },
                   site_code_number: { type: :integer, example: 'KAC' }
                 }
               }
        run_test!
      end
    end

    post('create site') do
      tags TAG
      consumes 'application/json'
      produces 'application/json'
      parameter name: :site, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Kamuzu Academy Clinic' },
          district: { type: :string, example: 'kasungu' },
          x: { type: :number, format: :float, example: 33.6884 },
          y: { type: :number, format: :float, example: -13.0294 },
          region: { type: :string, example: 'Central' },
          description: { type: :string, example: 'Clinic' },
          enabled: { type: :boolean, example: false },
          site_code: { type: :string, example: '' },
          application_port: { type: :string, example: '0000' },
          host_address: { type: :string, example: '' },
          couch_username: { type: :string, example: '' },
          couch_password: { type: :string, example: '' },
          created_at: { type: :string, format: 'date-time', example: '2021-07-29T11:24:55.000+02:00' },
          updated_at: { type: :string, format: 'date-time', example: '2021-07-29T11:24:55.000+02:00' },
          site_code_number: { type: :integer, example: 'KAC' }
        }
      }
      response(200, 'successful') do
        schema type: :object,
                properties: {
                  id: { type: :integer, example: 2331 },
                  name: { type: :string, example: 'Kamuzu Academy Clinic' },
                  district: { type: :string, example: 'kasungu' },
                  x: { type: :number, format: :float, example: 33.6884 },
                  y: { type: :number, format: :float, example: -13.0294 },
                  region: { type: :string, example: 'Central' },
                  description: { type: :string, example: 'Clinic' },
                  enabled: { type: :boolean, example: false },
                  sync_status: { type: :boolean, example: false },
                  site_code: { type: :string, example: '' },
                  application_port: { type: :string, example: '0000' },
                  host_address: { type: :string, example: '' },
                  couch_username: { type: :string, example: '' },
                  couch_password: { type: :string, example: '' },
                  created_at: { type: :string, format: 'date-time', example: '2021-07-29T11:24:55.000+02:00' },
                  updated_at: { type: :string, format: 'date-time', example: '2021-07-29T11:24:55.000+02:00' },
                  site_code_number: { type: :integer, example: 'KAC' }
                }
        run_test!
      end
    end
  end

  path '/api/v1/sites/{id}' do
    parameter name: 'id', in: :path, type: :integer, description: 'id'
    get('show site') do
      tags TAG
      produces 'application/json'
      response(200, 'successful') do
        schema type: :object,
                properties: {
                  id: { type: :integer, example: 2331 },
                  name: { type: :string, example: 'Kamuzu Academy Clinic' },
                  district: { type: :string, example: 'kasungu' },
                  x: { type: :number, format: :float, example: 33.6884 },
                  y: { type: :number, format: :float, example: -13.0294 },
                  region: { type: :string, example: 'Central' },
                  description: { type: :string, example: 'Clinic' },
                  enabled: { type: :boolean, example: false },
                  sync_status: { type: :boolean, example: false },
                  site_code: { type: :string, example: '' },
                  application_port: { type: :string, example: '0000' },
                  host_address: { type: :string, example: '' },
                  couch_username: { type: :string, example: '' },
                  couch_password: { type: :string, example: '' },
                  created_at: { type: :string, format: 'date-time', example: '2021-07-29T11:24:55.000+02:00' },
                  updated_at: { type: :string, format: 'date-time', example: '2021-07-29T11:24:55.000+02:00' },
                  site_code_number: { type: :integer, example: 'KAC' }
                }
        run_test!
      end
    end

    put('update site') do
      tags TAG
      consumes 'application/json'
      produces 'application/json'
      parameter name: :site, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Kamuzu Academy Clinic' },
          district: { type: :string, example: 'kasungu' },
          x: { type: :number, format: :float, example: 33.6884 },
          y: { type: :number, format: :float, example: -13.0294 },
          region: { type: :string, example: 'Central' },
          description: { type: :string, example: 'Clinic' },
          enabled: { type: :boolean, example: false },
          site_code: { type: :string, example: '' },
          application_port: { type: :string, example: '0000' },
          host_address: { type: :string, example: '' },
          couch_username: { type: :string, example: '' },
          couch_password: { type: :string, example: '' },
          created_at: { type: :string, format: 'date-time', example: '2021-07-29T11:24:55.000+02:00' },
          updated_at: { type: :string, format: 'date-time', example: '2021-07-29T11:24:55.000+02:00' },
          site_code_number: { type: :integer, example: 'KAC' }
        }
      }
      response(200, 'successful') do
        schema type: :object,
                properties: {
                  id: { type: :integer, example: 2331 },
                  name: { type: :string, example: 'Kamuzu Academy Clinic' },
                  district: { type: :string, example: 'kasungu' },
                  x: { type: :number, format: :float, example: 33.6884 },
                  y: { type: :number, format: :float, example: -13.0294 },
                  region: { type: :string, example: 'Central' },
                  description: { type: :string, example: 'Clinic' },
                  enabled: { type: :boolean, example: false },
                  sync_status: { type: :boolean, example: false },
                  site_code: { type: :string, example: '' },
                  application_port: { type: :string, example: '0000' },
                  host_address: { type: :string, example: '' },
                  couch_username: { type: :string, example: '' },
                  couch_password: { type: :string, example: '' },
                  created_at: { type: :string, format: 'date-time', example: '2021-07-29T11:24:55.000+02:00' },
                  updated_at: { type: :string, format: 'date-time', example: '2021-07-29T11:24:55.000+02:00' },
                  site_code_number: { type: :integer, example: 'KAC' }
                }
        run_test!
      end
    end
  end
end
