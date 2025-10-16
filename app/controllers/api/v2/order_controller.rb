class API::V2::OrderController < ApplicationController
  before_action :remote_host, only: %i[request_order]
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
      if params['tracking_number']
        tracking_number = params['tracking_number']
        order_availability = OrderService.check_order(tracking_number)
        if order_availability == true
          response = {
            status: 200,
            error: false,
            message: 'order already available',
            data: {
              tracking_number:
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
      res = OrderService.query_order_by_tracking_number_v2(
        params[:tracking_number],
        params[:test_name],
        params[:couch_id]
      )
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

  def create_order
    message = required_params
    if message.present?
      render json: { error: true, message: message, data: {} }, status: :unprocessable_entity and return
    end

    specimen = Speciman.find_by(tracking_number: params[:order][:tracking_number])
    if specimen.present?
      render json: {
        error: false,
        message: 'order already available',
        data: { tracking_number: specimen.tracking_number }
      }, status: :created and return
    end

    status, response = OrderService.create_order_v2(params)
    if status == true
      if params[:tests].present?
        params[:tests].each do |lab_test|
          OrderService.update_tests(lab_test)
        end
      end
      render json: {
        error: false,
        message: 'order created successfuly',
        data: { tracking_number: response }
      }, status: :created
    else
      render json: {
        error: true,
        message: response,
        data: {}
      }, status: :unprocessable_entity
    end
  end

  def update_tests
    status, response = OrderService.update_tests(params)
    if status == true
      render json: {
        error: false,
        message: response,
        data: {}
      }, status: :ok
    else
      render json: {
        error: true,
        message: response,
        data: {}
      }, status: :unprocessable_entity
    end
  end

  def create_order_once_off
    message = required_params
    if message.present?
      render json: { error: true, message: message, data: {} }, status: :unprocessable_entity and return
    end

    specimen = Speciman.find_by(tracking_number: params[:order][:tracking_number])
    if specimen.present?
      if params[:tests].present?
        params[:tests].each do |lab_test|
          OrderService.update_tests(lab_test)
        end
      end
      render json: {
        error: false,
        message: 'order already available',
        data: { tracking_number: specimen.tracking_number }
      }, status: :created and return
    end

    status, response = OrderService.create_order_v2(params)
    if status == true
      if Config.local_nlims?
        nlims = NlimsSyncUtilsService.new(nil)
        nlims.once_off_push_orders_to_master_nlims(response, once_off: true)
      end
      if params[:tests].present?
        params[:tests].each do |lab_test|
          OrderService.update_tests(lab_test)
        end
      end
      render json: {
        error: false,
        message: 'order created successfuly',
        data: { tracking_number: response }
      }, status: :created
    else
      render json: {
        error: true,
        message: response,
        data: {}
      }, status: :unprocessable_entity
    end
  end

  def find_order_by_tracking_number
    order = Speciman.find_by(tracking_number: params[:tracking_number])
    if params[:couch_id].present?
      order = Speciman.find_by(tracking_number: params[:tracking_number], couch_id: params[:couch_id])
    end
    if order.nil?
      render json: { error: true, message: 'Order Not Available', data: {} }, status: :not_found and return
    end
    render json: { error: false, message: 'Order Found', data: OrderSerializer.serialize(order) }, status: :ok
  end

  private

  def remote_host
    return unless params[:tracking_number].present?

    TrackingNumberHost.find_or_create_by(
      tracking_number: params[:tracking_number],
      source_host: request.remote_ip,
      source_app_uuid: User.find_by(token: request.headers['token'])&.app_uuid
    )
  end

  def required_params
    required = {
      %i[order district] => 'district not provided',
      %i[order sending_facility] => 'health facility name not provided',
      %i[order tracking_number] => 'tracking number not provided',
      %i[order requested_by] => 'requesting clinician not provided',
      %i[patient first_name] => 'patient first name not provided',
      %i[patient last_name] => 'patient last name not provided',
      %i[patient gender] => 'patient gender not provided',
      %i[order sample_type name] => 'sample type not provided',
      [:tests] => 'tests not provided',
      %i[order date_created] => 'date for sample drawn not provided',
      %i[order sample_status name] => 'sample status not provided',
      %i[order priority] => 'sample priority level not provided',
      %i[order target_lab] => 'target lab for sample not provided',
      %i[order order_location] => 'sample order location not provided',
      %i[order drawn_by name] => 'first name for person ordering not provided',
      %i[order drawn_by id] => 'last name for person ordering not provided'
    }

    required.each do |path, message|
      value = params.dig(*path.map(&:to_s))
      return message if value.blank?
    end

    nil
  end
end
