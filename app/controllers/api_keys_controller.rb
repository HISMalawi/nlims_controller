# frozen_string_literal: true

# Issuing, rotating and revoking the keys a client authenticates with.
#
# The secret exists in this process for the length of one response and is never
# stored, so `create` renders rather than redirects: a redirect would have to
# carry the secret through the flash, which is a cookie, which is precisely
# where a key must not be written.
class ApiKeysController < ApplicationController
  before_action :require_admin
  before_action :set_client

  def new
    @scopes = ApiKey::SCOPES
    @suggested = suggested_scopes
  end

  def create
    scopes = Array(params[:scopes]).map(&:to_s) & ApiKey::SCOPES

    if scopes.empty?
      @scopes = ApiKey::SCOPES
      @suggested = suggested_scopes
      flash.now[:alert] = t(".no_scopes")
      return render :new, status: :unprocessable_content
    end

    @key, @token = ApiKey.issue!(
      api_client: @client,
      scopes: scopes,
      expires_at: parse_expiry,
      issued_by: current_user.to_actor
    )

    render :created, status: :created
  end

  # A new key with the same permissions, and the old one deliberately left
  # working. Revoking on the spot would cut the client off at the moment the
  # operator is least able to fix it; the old key is revoked by hand once the
  # integration has been pointed at the new one.
  def rotate
    old = @client.api_keys.find(params[:id])

    @key, @token = ApiKey.issue!(
      api_client: @client,
      scopes: old.scopes,
      expires_at: old.expires_at,
      issued_by: current_user.to_actor
    )

    @rotated_from = old
    render :created, status: :created
  end

  def destroy
    key = @client.api_keys.find(params[:id])
    key.revoke!

    redirect_to api_client_path(@client), notice: t(".revoked", prefix: key.prefix)
  end

  private

  def set_client
    @client = ApiClient.find(params[:api_client_id])
  end

  # What a client of this kind actually needs. Offered as a starting point and
  # not enforced: the commonest way a key ends up over-privileged is somebody
  # ticking every box because they are not sure which ones matter.
  def suggested_scopes
    case @client.kind
    when "emr" then %w[orders:write orders:read results:read dictionary:read]
    when "sislab" then %w[orders:read results:write referrals:write dictionary:read]
    when "node" then %w[sync:push sync:pull dictionary:read]
    else []
    end
  end

  def parse_expiry
    Date.parse(params[:expires_on].to_s).end_of_day
  rescue ArgumentError, TypeError
    nil
  end
end
