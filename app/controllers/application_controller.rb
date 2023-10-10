# frozen_string_literal: true

require 'user_service'
# application controller
class ApplicationController < ActionController::API
    before_action :authenticate_request, :except => [
                                            "re_authenticate", "check_token_validity", "authenticate_user", "create_user", "dispatch_sample"
                                        ]
    

    def authenticate_request
        
        token = request.headers['token']
        status = UserService.check_token(token)
        if token
            if status ==  false
        
                response = {
                    status: 401,
                    error: true,
                    message: 'token expired',
                    data: {
                        
                    }
                }                
                
            else
                return status
            end
        else
            response = {
                    status: 401,
                    error: true,
                    message: 'token not provided',
                    data: {
                        
                    }
                }
        end
        render plain: response.to_json and return
    end
  
end
