# frozen_string_literal: true

# Status controller for tracking app status
class API::V1::StatusController < ApplicationController
  skip_before_action :authenticate_request, only: [:ping]

  def ping
    git_describe = `git describe --tags --abbrev=0`.strip
    render json: { ping: true, time: Time.now, version: git_describe.empty? ? 'N/A' : git_describe }, status: :ok
  end
end
