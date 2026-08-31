# frozen_string_literal: true

# Sign-in for the browser interface. Nothing here touches API keys: a person
# with a password can open these screens and cannot call the API, and a system
# holding a key can call the API and cannot open these screens.
module Authentication
  extend ActiveSupport::Concern

  COOKIE = :sislab_session

  included do
    before_action :require_authentication
    helper_method :current_user, :current_session, :signed_in?
  end

  class_methods do
    # For the sign-in screen itself, which cannot require being signed in.
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  def current_session
    return @current_session if defined?(@current_session)

    @current_session = resolve_session
  end

  def current_user
    current_session&.user
  end

  def signed_in?
    current_session.present?
  end

  def require_authentication
    return true if signed_in?

    # Where they were going, so signing in lands on the screen they asked for
    # rather than dropping them at the dashboard to navigate again. Only the
    # safe verbs: replaying a POST after a sign-in would repeat an action they
    # may no longer intend.
    session[:return_to] = request.fullpath if request.get? || request.head?

    redirect_to new_session_path, alert: t("auth.sign_in_required")
  end

  # Screens that change the dictionary or issue keys. Everyone who can sign in
  # can read everything and retry a failed event; these two are the operator's
  # authority to give, not to take.
  def require_admin
    return true if current_user&.admin?

    redirect_to root_path, alert: t("auth.admin_required")
  end

  def resolve_session
    id = cookies.signed[COOKIE]
    return nil if id.blank?

    record = Session.includes(:user).find_by(id: id)
    return nil if record.nil?

    # An expired session is destroyed on the way past rather than left to a
    # sweep job: the request that found it is the cheapest place to do it.
    if record.expired? || !record.user.active?
      record.destroy
      cookies.delete(COOKIE)
      return nil
    end

    record.touch_last_seen!
    Current.user = record.user
    record
  end

  def start_session_for(user)
    record = Session.start!(user: user, ip: request.remote_ip, user_agent: request.user_agent)

    cookies.signed.permanent[COOKIE] = {
      value: record.id,
      httponly: true,
      same_site: :lax,
      # The scheme the request actually came in on, not the environment name: a
      # node without TLS in front of it would set a cookie the browser keeps and
      # never sends back, and nobody would get past the sign-in page.
      secure: request.ssl?
    }

    user.update_column(:last_signed_in_at, Time.current)
    @current_session = record
  end

  def end_session
    current_session&.destroy
    cookies.delete(COOKIE)
    @current_session = nil
  end

  # Where they were trying to go before being asked to sign in.
  def after_sign_in_path
    session.delete(:return_to) || root_path
  end
end
