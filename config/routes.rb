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
          patch "orders/:tracking_number/status", to: "orders#status", as: :order_status
          post "orders/:tracking_number/results", to: "orders#results", as: :order_results
          post "orders/:tracking_number/tests", to: "orders#tests", as: :order_tests
          post "orders/:tracking_number/reject", to: "orders#reject", as: :reject_order

          post "referrals", to: "referrals#create"
          patch "referrals/:uuid", to: "referrals#update", as: :referral
        end
      end

      # Endpoints only the national node answers.
      if SislabSync.national?
        namespace :sync do
          post "events", to: "events#create"
          get "inbound", to: "inbound#index"
        end

        post "nodes/heartbeat", to: "nodes#heartbeat"
      end

      # The dictionary reads the same way in both modes: a local node pulls from
      # the national one, a SISLAB or EMR pulls from its local node.
      scope :dictionary, controller: :dictionary, as: :dictionary do
        get "changes", action: :changes, as: :changes
        get ":entity_type", action: :index, as: :entity, constraints: { entity_type: /[a-z_]+/ }
      end
    end
  end

  # The contract, served by the node it describes and narrowed to what this node
  # answers. Open to anyone who can reach the node: it is what a team reads
  # before they have a key. `.json` and `.yaml` give the OpenAPI document itself.
  get "api-docs", to: "api_docs#show", as: :api_docs

  # The operator interface. Everything below authenticates with a user session
  # and answers HTML; everything above authenticates with an API key and answers
  # JSON. Nothing crosses.
  resource :session, only: %i[new create destroy]

  # Addressed by tracking number, as everywhere else: it is what is written on
  # the tube and what an operator has in front of them.
  resources :orders, only: %i[index show], param: :tracking_number

  resources :referrals, only: :index

  # Clients are never deleted. A client that has called this node is part of the
  # audit trail; withdrawing it means marking it inactive.
  resources :api_clients, except: :destroy do
    resources :api_keys, only: %i[new create destroy] do
      post :rotate, on: :member
    end
  end

  resources :audits, only: :index

  # Readable in both modes, writable only on the national node — the same rule
  # the API follows, drawn the same way, so a local node has no route that could
  # invent a code nobody else has heard of.
  get "dictionary", to: "dictionary#index", as: :dictionary

  if SislabSync.national?
    post "dictionary/promote", to: "dictionary_entries#promote", as: :promote_dictionary
    get "dictionary/:entity_type/new", to: "dictionary_entries#new", as: :new_dictionary_entry
    post "dictionary/:entity_type", to: "dictionary_entries#create", as: :dictionary_entries
    get "dictionary/:entity_type/:national_code/edit", to: "dictionary_entries#edit", as: :edit_dictionary_entry
    patch "dictionary/:entity_type/:national_code", to: "dictionary_entries#update", as: :dictionary_entry
    post "dictionary/:entity_type/:national_code/activate", to: "dictionary_entries#activate",
         as: :activate_dictionary_entry
    post "dictionary/:entity_type/:national_code/retire", to: "dictionary_entries#retire",
         as: :retire_dictionary_entry
  end

  get "dictionary/:entity_type", to: "dictionary#show", as: :dictionary_entity,
      constraints: { entity_type: /[a-z_]+/ }

  # The outbox only exists on a node that produces events; the nodes table only
  # on the one that hears from them.
  if SislabSync.local?
    get "sync-queue", to: "sync_queue#index", as: :sync_queue
    post "sync-queue/retry-all", to: "sync_queue#retry_all", as: :retry_all_sync_events
    post "sync-queue/:id/retry", to: "sync_queue#retry", as: :retry_sync_event
  end

  resources :nodes, only: :index if SislabSync.national?

  root "dashboard#show"
end
