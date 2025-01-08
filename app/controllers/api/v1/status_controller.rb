# frozen_string_literal: true

# Status controller for tracking app status
class API::V1::StatusController < ApplicationController
  skip_before_action :authenticate_request, only: [:ping]

  def ping
    render json: { ping: true, time: Time.now }, status: :ok
  end
end
