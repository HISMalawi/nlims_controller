require 'test_service'
require 'user_service'

class API::V1::TestController < ApplicationController
  def update_test
    update_details = params
    if update_details
      order_availability = OrderService.check_order(update_details['tracking_number'])
      if order_availability == false
        response = {
          status: 200,
          error: false,
          message: 'order not available',
          data: {
            tracking_number: update_details['tracking_number']
          }
        }
        render plain: response.to_json and return
      end
      stat = TestService.update_test(params)
      response = if stat[0] == true
                   {
                     status: 200,
                     error: false,
                     message: 'test updated successfuly',
                     data: {}
                   }
                 else
                   {
                     status: 401,
                     error: true,
                     message: stat[1],
                     data: {}
                   }

                 end
    else
      response = {
        status: 401,
        error: true,
        message: 'update details not provided',
        data: {}
      }
    end
    render plain: response.to_json and return
  end

  def test_no_results
    npid = params[:npid]
    res = TestService.test_no_results(npid)
    response = if res[0] == true
                 {	status: 200,
                   error: false,
                   message: 'test retrieved successfuly',
                   data: res[1] }
               else
                 {
                   status: 401,
                   error: true,
                   message: 'no test pending for results',
                   data: {}
                 }
               end

    render plain: response.to_json and return
  end

  def query_test_status
    if params[:tracking_number]
      stat = TestService.query_test_status(params[:tracking_number])
      response = if stat[1] != false
                   {
                     status: 200,
                     error: false,
                     message: 'test measures retrieved successfuly',
                     data: stat[1]
                   }
                 else
                   {
                     status: 401,
                     error: true,
                     message: 'no tests were ordered for the specimen',
                     data: {}
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

  def query_test_measures
    if params[:test_name]
      stat = TestService.query_test_measures(params[:test_name])
      response = if stat != false
                   {
                     status: 200,
                     error: false,
                     message: 'test measures retrieved successfuly',
                     data: stat
                   }
                 else
                   {
                     status: 401,
                     error: true,
                     message: 'test measures retrievel failed',
                     data: {}
                   }

                 end
    else
      response = {
        status: 401,
        error: true,
        message: 'test name not provided',
        data: {}
      }

    end
    render plain: response.to_json and return
  end

  def retrieve_order_location
    dat = TestService.retrieve_order_location
    response = if dat == false
                 {
                   status: 401,
                   error: true,
                   message: 'test catelog not available',
                   data: {}
                 }
               else
                 {
                   status: 200,
                   error: false,
                   message: 'test added successfuly',
                   data: dat
                 }
               end
    render plain: response.to_json and return
  end

  def retrieve_target_labs
    dat = TestService.retrieve_target_labs
    response = if dat == false
                 {
                   status: 401,
                   error: true,
                   message: 'test catelog not available',
                   data: {}
                 }
               else
                 {
                   status: 200,
                   error: false,
                   message: 'test added successfuly',
                   data: dat
                 }
               end
    render plain: response.to_json and return
  end

  def retrieve_test_catelog
    dat = TestService.retrieve_test_catelog
    response = if dat == false
                 {
                   status: 401,
                   error: true,
                   message: 'test catelog not available',
                   data: {}
                 }
               else
                 {
                   status: 200,
                   error: false,
                   message: 'test added successfuly',
                   data: dat
                 }
               end
    render plain: response.to_json and return
  end

  def add_test
    test_details = params
    if test_details
      res = TestService.add_test(params)
      response = if res == true
                   {
                     status: 200,
                     error: false,
                     message: 'test added successfuly',
                     data: {}
                   }
                 else
                   {
                     status: 401,
                     error: true,
                     message: res[1],
                     data: {}
                   }

                 end
    else
      response = {
        status: 401,
        error: true,
        message: 'test details not provided',
        data: {}
      }
    end
    render plain: response.to_json and return
  end

  def edit_test_result
    test_details  = params
    if test_details
      stat = TestService.edit_test_result(params)
      response = if stat == true
                   {
                     status: 200,
                     error: false,
                     message: 'test results edited successfuly',
                     data: {}
                   }
                 else
                   {
                     status: 401,
                     error: true,
                     message: 'test result edit failed',
                     data: {}
                   }

                 end
    else
      response = {
        status: 401,
        error: true,
        message: 'test result details not provided',
        data: {}
      }
    end
    render plain: response.to_json and return
  end

  def acknowledge_test_results_receiptient
    msg = ''
    details = params
    tracking_number = details['tracking_number']
    test_name = details['test']
    date_acknowledged = details['date_acknowledged']
    recipient_type = details['recipient_type']
    if !details['tracking_number']
      msg = 'no tracking number provided'
    elsif !details['test']
      msg = 'no test whose result being acknowledged is provided'
    elsif !details['recipient_type']
      msg = 'no acknowledged type for the result provided'
    elsif !details['date_acknowledged']
      msg = 'no date for acknowlegment is provided'
    else
      res = TestService.acknowledge_test_results_receiptient(tracking_number, test_name, date_acknowledged.to_time,
                                                             recipient_type)
      response = if res == true
                   {
                     status: 200,
                     error: false,
                     message: 'results delivered successfuly',
                     data: {}
                   }
                 else
                   {
                     status: 401,
                     error: true,
                     message: 'test result status update failed',
                     data: {}
                   }

                 end
    end
    unless msg.blank?
      response = {
        status: 401,
        error: true,
        message: msg,
        data: {}
      }
    end
    render plain: response.to_json and return
  end

  private

  def socket_status
    begin
      settings = YAML.load_file("#{Rails.root}/config/results_channel_socket.yml", aliases: true)
      @socket_url = "http://#{settings['host']}:#{settings['port']}"
    rescue StandardError
      @socket_url = 'http://localhost:3011'
    end
    begin
      RestClient.get(@socket_url)
      true
    rescue StandardError
      false
    end
  end
end
