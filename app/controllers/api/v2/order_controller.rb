require 'order_service'
require 'user_service'
require 'tracking_number_service'

class API::V2::OrderController < ApplicationController
  def request_order
    if !params['district']
      msg = 'district not provided'
    elsif !params['health_facility_name']
      msg = 'health facility name not provided'
    elsif !params['requesting_clinician']
      msg = 'requesting clinician not provided'
    elsif !params['first_name']
      msg = 'patient first name not provided'
    elsif !params['last_name']
      msg = 'patient last name not provided'
    elsif !params['phone_number']
      msg = 'patient phone number not provided'
    elsif !params['gender']
      msg = 'patient gender not provided'
    elsif !params['national_patient_id']
      msg = 'patient ID not provided'
    elsif !params['tests']
      msg = 'tests not provided'
    elsif !params['date_sample_drawn']
      msg = 'date for sample drawn not provided'
    elsif !params['sample_priority']
      msg = 'sample priority level not provided'
    elsif !params['order_location']
      msg = 'sample order location not provided'
    elsif !params['who_order_test_first_name']
      msg = 'first name for person ordering not provided'
    elsif !params['who_order_test_last_name']
      msg = 'last name for person ordering not provided'
    else
      order_availability = false
      if params['tracking_number']
        tracking_number = params['tracking_number']
        order_availability = OrderService.check_order(tracking_number)
        if order_availability == true
          response = {
            status: 200,
            error: false,
            message: 'order already available',
            data: {
              tracking_number: tracking_number
            }
          }
          render plain: response.to_json and return
        end
      else
        tracking_number = TrackingNumberService.generate_tracking_number
      end
      st = OrderService.request_order(params, tracking_number)
      if st[0] == true
        response = {
          status: 200,
          error: false,
          message: 'order created successfuly',
          data: {
            tracking_number: st[1],
            couch_id: st[2]
          }
        }
      end
    end

    if msg
      response = {
        status: 401,
        error: true,
        message: msg,
        data: {}
      }
    end

    render plain: response.to_json and return
  end

  def query_order_by_tracking_number
    if params[:tracking_number]
      res = OrderService.query_order_by_tracking_number_v2(params[:tracking_number], params[:test_name])
      response = if res == false
                   {
                     status: 200,
                     error: true,
                     message: 'order not available',
                     data: {}
                   }
                 else
                   {
                     status: 200,
                     error: false,
                     message: 'order retrieved',
                     data: {
                       tests: res[:tests],
                       other: res[:gen_details]
                     }
                   }
                 end
    else
      response = {
        status: 401,
        error: true,
        message: 'tracking number not provided',
        data: {}
      }
    end

    render plain: response.to_json and return
  end

  def confirm_order_request
    if params['tracking_number'] && params['specimen_type']	&& params['target_lab']
      OrderService.confirm_order_request(params)
      response = {
        status: 200,
        error: false,
        message: 'order request confirmed successfuly',
        data: {}
      }
    else
      response = {
        status: 401,
        error: true,
        message: 'missing parameter, please check',
        data: {}
      }
    end
    render plain: response.to_json and return
  end
end
