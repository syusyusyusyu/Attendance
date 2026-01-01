Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "/service-worker.js", to: "rails/pwa#service_worker", as: :pwa_service_worker

  root "dashboard#show"

  get "/login", to: "sessions#new"
  post "/login", to: "sessions#create"
  delete "/logout", to: "sessions#destroy"
  get "/terms", to: "legal#terms"
  get "/privacy", to: "legal#privacy"
  get "/data-policy", to: "legal#data_policy"

  get "/scan", to: "qr_scans#new"
  post "/scan", to: "qr_scans#create"
  get "/generate-qr", to: "qr_codes#show"
  get "/scan-logs", to: "qr_scan_events#index"
  get "/attendance-logs", to: "attendance_changes#index", as: :attendance_logs
  get "/reports", to: "reports#index"
  get "/notifications", to: "notifications#index"
  patch "/notifications/mark-all", to: "notifications#mark_all"
  get "/admin", to: "admin_dashboard#index"

  namespace :admin do
    resources :users, only: [:index, :new, :create, :edit, :update]
    resources :roles, only: [:index, :update]
    resources :operation_requests, only: [:index, :update]
    resources :devices, only: [:index, :update]
    resources :api_keys, only: [:index, :create, :update]
    resources :sso_providers, only: [:index, :create, :edit, :update]
  end

  get "/history", to: "attendance_history#show"
  get "/history/export", to: "attendance_history#export", as: :attendance_history_export
  get "/attendance", to: "class_attendances#show"
  patch "/attendance", to: "class_attendances#update"
  get "/attendance/export", to: "class_attendances#export"
  post "/attendance/import", to: "class_attendances#import"
  patch "/attendance/policy", to: "class_attendances#update_policy"
  patch "/attendance/finalize", to: "class_attendances#finalize", as: :attendance_finalize
  patch "/attendance/unlock", to: "class_attendances#unlock", as: :attendance_unlock

  resources :attendance_requests, only: [:index, :create, :update] do
    patch :bulk_update, on: :collection
  end

  resource :profile, only: [:show, :update]
  resource :push_subscription, only: [:create, :destroy], path: "push-subscription"
  resources :devices, only: [:update] do
    post :request_approval, on: :member
  end

  resources :school_classes do
    post :roster_import, on: :member
    resources :enrollments, only: [:create, :destroy]
    resources :class_session_overrides, only: [:create, :destroy]
  end

  namespace :api do
    namespace :v1 do
      resources :classes, only: [:index, :show] do
        get :attendance_records, on: :member
        get :students, on: :member
      end
    end
  end
end
