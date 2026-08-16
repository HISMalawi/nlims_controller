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
        # S7 — EMR: order-requests, orders, results
        # S8 — SISLAB: lab/pending-orders, lab/orders/:tn/*, lab/referrals
      end

      # Endpoints only the national node answers.
      if SislabSync.national?
        # S9 — sync/events, nodes/heartbeat
        # S10 — sync/inbound
      end

      # S5 — dictionary/changes, served by both modes.
    end
  end

  root "dashboard#show"
end
