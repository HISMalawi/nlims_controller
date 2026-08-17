# frozen_string_literal: true

# Base for the operator interface. The API does not inherit from this — see
# Api::BaseController, which authenticates with keys and answers JSON.
class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # A tracking number typed with a digit wrong, or a link followed after the row
  # was gone, is an ordinary thing to do — not a 500.
  rescue_from ActiveRecord::RecordNotFound do
    redirect_back fallback_location: root_path, alert: t("errors.not_found")
  end
end
