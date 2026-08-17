Rails.application.routes.draw do
  # Reveals what this node is without authentication, so an operator or a load
  # balancer can tell a local node from the national one.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v3 do
      get "health", to: "health#show"
      get "me", to: "me#show"

      # Endpoints the EMR and the SISLAB call. A national node has no clients of
      # this kind, so the routes simply do not exist there.
      if SislabSync.local?
        post "order-requests", to: "order_requests#create"

        # The tracking number is the identifier here, not an id: it is what the
        # EMR was given, what is written on the tube, and what an operator has
        # in front of them when they telephone.
        get "orders/:tracking_number", to: "orders#show", as: :order
        get "orders/:tracking_number/results", to: "orders#results", as: :order_results

        get "results", to: "results#index"
        post "results/:uuid/acknowledge", to: "results#acknowledge", as: :acknowledge_result

        # The laboratory polls and publishes; the node never calls it.
        namespace :lab do
          get "pending-orders", to: "orders#pending"
          post "orders/:tracking_number/claim", to: "orders#claim", as: :claim_order
        end
      end

      # Endpoints only the national node answers.
      if SislabSync.national?
        # S9 — sync/events, nodes/heartbeat
        # S10 — sync/inbound
      end

      # The dictionary reads the same way in both modes: a local node pulls from
      # the national one, a SISLAB or EMR pulls from its local node.
      scope :dictionary, controller: :dictionary, as: :dictionary do
        get "changes", action: :changes, as: :changes
        get ":entity_type", action: :index, as: :entity, constraints: { entity_type: /[a-z_]+/ }
      end
    end
  end

  root "dashboard#show"
end
