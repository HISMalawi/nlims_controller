# frozen_string_literal: true

# Status controller for tracking app status
class API::V1::StatusController < ApplicationController
  skip_before_action :authenticate_request, only: %i[ping check_in]

  def ping
    git_describe = `git describe --tags --abbrev=0`.strip
    app_target = begin
      Config.local_nlims? ? 'Local Nlims' : 'Master Nlims'
    rescue StandardError
      'N/A'
    end
    AppCheckInJob.perform_async(params[:site_id]) if Config.local_nlims?
    version = git_describe.empty? ? "N/A (#{app_target})" : "#{git_describe} (#{app_target})"
    render json: { ping: true, time: Time.now, version: version }, status: :ok
  end

  def check_in
    site = Site.find_by(id: params[:site_id])
    return render(json: { error: 'Site not found' }, status: :not_found) unless site.present?

    check_in = AppCheckIn.create!(
      site_id: site.id,
      name: site.name,
      ip_address: request.remote_ip,
      check_in_time: Time.now
    )
    render json: { message: 'Check-in recorded', check_in: check_in }, status: :ok
  end
end
