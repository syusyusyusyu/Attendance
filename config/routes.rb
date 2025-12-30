Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "dashboard#show"

  get "/login", to: "sessions#new"
  post "/login", to: "sessions#create"
  delete "/logout", to: "sessions#destroy"

  get "/scan", to: "qr_scans#new"
  post "/scan", to: "qr_scans#create"
  get "/generate-qr", to: "qr_codes#show"
  get "/scan-logs", to: "qr_scan_events#index"

  get "/history", to: "attendance_history#show"
  get "/attendance", to: "class_attendances#show"
  patch "/attendance", to: "class_attendances#update"
  get "/attendance/export", to: "class_attendances#export"
  post "/attendance/import", to: "class_attendances#import"
  patch "/attendance/policy", to: "class_attendances#update_policy"

  resource :profile, only: [:show, :update]
end
