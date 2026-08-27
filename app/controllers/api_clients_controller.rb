# frozen_string_literal: true

# The systems allowed to call this node, and the keys they call it with.
#
# Administrators only. Everyone who can sign in can read the rest of the
# interface and put a failed event back in the queue; deciding which system may
# write orders into this laboratory is a different kind of decision.
class ApiClientsController < ApplicationController
  before_action :require_admin
  before_action :set_client, only: %i[show edit update]

  def index
    @clients = ApiClient.left_joins(:api_keys)
                        .select("api_clients.*, COUNT(api_keys.id) AS keys_count, MAX(api_keys.last_used_at) AS last_used_at")
                        .group("api_clients.id")
                        .order(:kind, :name)
  end

  def show
    @keys = @client.api_keys.order(revoked_at: :asc, created_at: :desc)
    @recent_requests = RequestAudit.where(api_client: @client).order(created_at: :desc).limit(20)
  end

  def new
    @client = ApiClient.new(kind: ApiClient::KINDS.first, active: true)
  end

  def create
    @client = ApiClient.new(client_params)

    return render :new, status: :unprocessable_content unless @client.save

    redirect_to api_client_path(@client), notice: t(".created", name: @client.name)
  end

  def edit; end

  def update
    return render :edit, status: :unprocessable_content unless @client.update(client_params)

    redirect_to api_client_path(@client), notice: t(".updated", name: @client.name)
  end

  private

  def set_client
    @client = ApiClient.find(params[:id])
  end

  # `kind` decides which facility and lab checks apply to every request the
  # client makes, so it is set once at creation and not editable afterwards:
  # changing it would silently re-scope keys that are already in the field.
  def client_params
    # The codes are no longer offered by the form on a local node: they come
    # from the node itself. They stay permitted for the national node, which
    # issues keys on behalf of laboratories other than its own.
    permitted = params.require(:api_client).permit(:name, :kind, :facility_code, :lab_code, :active)
    permitted.delete(:kind) if @client&.persisted?
    permitted
  end
end
